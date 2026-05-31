import AppKit
import Combine
import SwiftUI

enum ScreenshotState: Equatable {
    case idle
    case selecting
    case selected
    case annotating
    case ocrLoading
    case ocrResult(text: String)
}

@MainActor
final class ScreenshotViewModel: ObservableObject {
    @Published var state: ScreenshotState = .idle
    @Published var selection: CGRect = .zero
    @Published var capturedImage: CGImage?
    @Published var activeScreenSize: CGSize = .zero

    @Published var config = CaptureConfig()
    @Published var annotationEngine = AnnotationEngine()
    @Published var currentTool: AnnotationType?
    @Published var annotationPreviewPoints: [CGPoint] = []
    @Published var pendingTextPoint: CGPoint?
    @Published var textDraft = ""

    @Published var isShowingOverlay = false
    @Published var toastMessage: String?
    @Published var isShowingToast = false

    var onHideOverlay: (() -> Void)?
    var onShowOverlay: (() -> Void)?

    private var safetyTimer: Timer?
    private var ocrRequestID = UUID()
    private var cancellables = Set<AnyCancellable>()
    private let safetyTimeout: TimeInterval = 300
    private let minimumSelectionSize = CGSize(width: 20, height: 20)

    init() {
        annotationEngine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var hasUsableSelection: Bool {
        selection.width >= minimumSelectionSize.width && selection.height >= minimumSelectionSize.height
    }

    func startCapture(screen: NSScreen = .main ?? NSScreen.screens[0], preCapturedImage: CGImage? = nil) {
        guard ScreenCaptureService.checkPermission() else {
            ScreenCaptureService.requestPermission()
            return
        }

        guard let image = preCapturedImage ?? ScreenCaptureService.captureScreen(screen) else {
            showToast("截图失败")
            return
        }

        capturedImage = image
        activeScreenSize = screen.frame.size
        selection = .zero
        annotationEngine.clearAll()
        annotationPreviewPoints = []
        currentTool = nil
        pendingTextPoint = nil
        textDraft = ""
        state = .selecting
        isShowingOverlay = true
        startSafetyTimer()
    }

    func updateSelection(_ rect: CGRect) {
        ocrRequestID = UUID()
        selection = clamped(rect)
    }

    func finishSelection() {
        guard hasUsableSelection else {
            resetSelection()
            return
        }
        currentTool = nil
        annotationPreviewPoints = []
        pendingTextPoint = nil
        textDraft = ""
        state = .selected
    }

    func resetSelection() {
        selection = .zero
        currentTool = nil
        annotationPreviewPoints = []
        pendingTextPoint = nil
        textDraft = ""
        annotationEngine.clearAll()
        state = .selecting
    }

    func moveSelection(from original: CGRect, translation: CGSize) {
        ocrRequestID = UUID()
        selection = ScreenshotGeometry.movedSelection(
            original,
            translation: translation,
            bounds: activeScreenSize
        )
    }

    func resizeSelection(from original: CGRect, handle: ScreenshotResizeHandle, translation: CGSize) {
        ocrRequestID = UUID()
        selection = ScreenshotGeometry.resizedSelection(
            original,
            handle: handle,
            translation: translation,
            bounds: activeScreenSize,
            minimumSize: minimumSelectionSize
        )
    }

    func enterAnnotationMode() {
        guard hasUsableSelection else { return }
        state = .annotating
    }

    func setTool(_ tool: AnnotationType?) {
        if currentTool == tool {
            currentTool = nil
            annotationPreviewPoints = []
            pendingTextPoint = nil
            textDraft = ""
            state = .selected
            return
        }

        currentTool = tool
        if tool != nil {
            enterAnnotationMode()
        }
    }

    func addTextAnnotation(at point: CGPoint, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        annotationEngine.add(annotationEngine.createText(at: point, text: trimmed))
    }

    func beginTextAnnotation(at point: CGPoint) {
        pendingTextPoint = point
        textDraft = ""
    }

    func commitTextAnnotation() {
        guard let point = pendingTextPoint else { return }
        addTextAnnotation(at: point, text: textDraft)
        pendingTextPoint = nil
        textDraft = ""
    }

    func cancelTextAnnotation() {
        pendingTextPoint = nil
        textDraft = ""
    }

    func undo() {
        annotationEngine.undo()
    }

    func performOCR() {
        let requestID = UUID()
        ocrRequestID = requestID
        let selectionSnapshot = selection
        let screenSizeSnapshot = activeScreenSize

        guard let image = capturedImage,
              hasUsableSelection,
              let croppedImage = AnnotationRenderer.cropForOCR(
                baseImage: image,
                selection: selectionSnapshot,
                screenSize: screenSizeSnapshot
              ) else {
            return
        }

        state = .ocrLoading
        Task {
            do {
                let text = try await OCRService.recognizeText(in: croppedImage)
                guard self.ocrRequestID == requestID, self.selection == selectionSnapshot else { return }
                state = .ocrResult(text: text)
            } catch {
                guard self.ocrRequestID == requestID, self.selection == selectionSnapshot else { return }
                state = .ocrResult(text: "识别失败: \(error.localizedDescription)")
            }
        }
    }

    func copyOCRText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast("已复制文字")
    }

    func closeOCRPanel() {
        state = currentTool == nil ? .selected : .annotating
    }

    func saveToClipboard() {
        guard let image = renderFinalImage() else { return }
        ExportService.copyToClipboard(image)
        showToast("已复制到剪贴板")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.closeOverlay()
        }
    }

    func saveToFile() {
        guard let image = renderFinalImage() else { return }

        onHideOverlay?()
        if let url = ExportService.showSavePanel(image: image, defaultDirectory: config.saveDirectory) {
            showToast("已保存到 \(url.lastPathComponent)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.closeOverlay()
            }
        } else {
            onShowOverlay?()
        }
    }

    func renderFinalImage() -> NSImage? {
        guard let image = capturedImage, hasUsableSelection else { return nil }
        return AnnotationRenderer.render(
            baseImage: image,
            selection: selection,
            screenSize: activeScreenSize,
            annotations: annotationEngine.annotations
        )
    }

    func handleShortcut(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard isShowingOverlay else { return false }

        if keyCode == 53 {
            cancel()
            return true
        }

        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))
        let commandDown = nsFlags.contains(.command)

        if commandDown {
            switch keyCode {
            case 6:
                undo()
                return true
            case 8:
                saveToClipboard()
                return true
            case 1:
                saveToFile()
                return true
            case 31:
                performOCR()
                return true
            default:
                break
            }
        }

        switch keyCode {
        case 36:
            saveToClipboard()
            return true
        case 15:
            setTool(.rect)
            return true
        case 0:
            setTool(.arrow)
            return true
        case 35:
            setTool(.freehand)
            return true
        case 17:
            setTool(.text)
            return true
        case 46:
            setTool(.mosaic)
            return true
        default:
            return false
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        isShowingToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isShowingToast = false
            self.toastMessage = nil
        }
    }

    func closeOverlay() {
        cancelSafetyTimer()
        isShowingOverlay = false
        state = .idle
        selection = .zero
        activeScreenSize = .zero
        capturedImage = nil
        annotationEngine.clearAll()
        currentTool = nil
        annotationPreviewPoints = []
        pendingTextPoint = nil
        textDraft = ""
    }

    func cancel() {
        closeOverlay()
    }

    private func clamped(_ rect: CGRect) -> CGRect {
        guard activeScreenSize.width > 0, activeScreenSize.height > 0 else { return rect }
        let normalized = rect.standardized
        let x = max(0, min(normalized.origin.x, activeScreenSize.width))
        let y = max(0, min(normalized.origin.y, activeScreenSize.height))
        let maxWidth = activeScreenSize.width - x
        let maxHeight = activeScreenSize.height - y
        return CGRect(
            x: x,
            y: y,
            width: max(0, min(normalized.width, maxWidth)),
            height: max(0, min(normalized.height, maxHeight))
        )
    }

    private func startSafetyTimer() {
        cancelSafetyTimer()
        safetyTimer = Timer.scheduledTimer(withTimeInterval: safetyTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closeOverlay()
            }
        }
    }

    private func cancelSafetyTimer() {
        safetyTimer?.invalidate()
        safetyTimer = nil
    }
}

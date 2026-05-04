import SwiftUI
import Combine

/// 截图状态
enum ScreenshotState: Equatable {
    case idle
    case selecting        // 正在选区
    case selected         // 选区确定
    case annotating       // 标注中
    case ocrLoading       // OCR 识别中
    case ocrResult(text: String)  // OCR 结果展示
    
    static func == (lhs: ScreenshotState, rhs: ScreenshotState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.selecting, .selecting), (.selected, .selected),
             (.annotating, .annotating), (.ocrLoading, .ocrLoading):
            return true
        case (.ocrResult(let t1), .ocrResult(let t2)):
            return t1 == t2
        default:
            return false
        }
    }
}

/// 截图流程状态管理
@MainActor
class ScreenshotViewModel: ObservableObject {
    // MARK: - 状态
    @Published var state: ScreenshotState = .idle
    @Published var selection: CGRect = .zero
    @Published var capturedImage: CGImage?
    
    // MARK: - 配置
    @Published var config = CaptureConfig()
    
    // MARK: - 标注
    @Published var annotationEngine = AnnotationEngine()
    @Published var currentTool: AnnotationType?
    
    // MARK: - 内部状态
    @Published var isShowingOverlay = false
    @Published var toastMessage: String?
    @Published var isShowingToast = false
    
    // MARK: - 选区调整相关
    enum ResizeHandle {
        case none, nw, n, ne, e, se, s, sw, w
    }
    @Published var activeHandle: ResizeHandle = .none
    @Published var isDragging = false
    
    // MARK: - 操作
    
    /// 开始截图
    func startCapture() {
        guard ScreenCaptureService.checkPermission() else {
            ScreenCaptureService.requestPermission()
            return
        }
        
        capturedImage = ScreenCaptureService.captureFullScreen()
        state = .selecting
        isShowingOverlay = true
        selection = .zero
    }
    
    /// 完成选区
    func finishSelection() {
        guard selection.width >= 20 && selection.height >= 20 else {
            // 选区太小，重置
            resetSelection()
            return
        }
        state = .selected
    }
    
    /// 重置选区
    func resetSelection() {
        selection = .zero
        state = .selecting
    }
    
    /// 进入标注模式
    func enterAnnotationMode() {
        state = .annotating
    }
    
    /// 设置当前工具
    func setTool(_ tool: AnnotationType?) {
        currentTool = tool
    }
    
    /// 撤销
    func undo() {
        annotationEngine.undo()
    }
    
    // MARK: - OCR
    
    /// 执行 OCR 识别
    func performOCR() {
        guard let image = capturedImage else { return }
        
        // 裁剪选区图片
        guard let croppedImage = image.cropping(to: selection) else { return }
        
        state = .ocrLoading
        
        Task {
            do {
                let text = try await OCRService.recognizeText(in: croppedImage)
                state = .ocrResult(text: text)
            } catch {
                state = .ocrResult(text: "识别失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 复制 OCR 文字到剪贴板
    func copyOCRText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToast("已复制文字")
    }
    
    /// 关闭 OCR 面板
    func closeOCRPanel() {
        state = .annotating
    }
    
    // MARK: - 保存
    
    /// 保存到剪贴板
    func saveToClipboard() {
        guard let image = renderFinalImage() else { return }
        ExportService.copyToClipboard(image)
        showToast("已复制到剪贴板")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.closeOverlay()
        }
    }
    
    /// 保存到文件
    func saveToFile() {
        guard let image = renderFinalImage() else { return }
        
        if let url = ExportService.showSavePanel(image: image, defaultDirectory: config.saveDirectory) {
            showToast("已保存到 \(url.lastPathComponent)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.closeOverlay()
            }
        }
    }
    
    // MARK: - 渲染
    
    /// 渲染最终图片（原始截图 + 标注）
    func renderFinalImage() -> NSImage? {
        guard let cgImage = capturedImage else { return nil }
        
        let image = ExportService.nsImage(from: cgImage)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        
        let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                          pixelsWide: Int(size.width),
                                          pixelsHigh: Int(size.height),
                                          bitsPerSample: 8,
                                          samplesPerPixel: 4,
                                          hasAlpha: true,
                                          isPlanar: false,
                                          colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0,
                                          bitsPerPixel: 0)
        
        guard let bitmapRep = bitmapRep else { return nil }
        
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        guard let context = context else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        
        // 绘制原始图片
        image.draw(in: NSRect(origin: .zero, size: size))
        
        // 绘制标注
        drawAnnotations(in: context, size: size)
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let finalImage = bitmapRep.cgImage else { return nil }
        return ExportService.nsImage(from: finalImage)
    }
    
    /// 绘制标注到上下文
    private func drawAnnotations(in context: NSGraphicsContext, size: NSSize) {
        for annotation in annotationEngine.annotations {
            switch annotation.type {
            case .rect:
                drawRect(annotation, in: context)
            case .arrow:
                drawArrow(annotation, in: context)
            case .freehand:
                drawFreehand(annotation, in: context)
            case .text:
                drawText(annotation, in: context)
            case .mosaic:
                drawMosaic(annotation, in: context)
            }
        }
    }
    
    private func drawRect(_ annotation: Annotation, in context: NSGraphicsContext) {
        guard annotation.points.count >= 2 else { return }
        let start = annotation.points[0]
        let end = annotation.points[1]
        let rect = CGRect(x: min(start.x, end.x),
                          y: min(start.y, end.y),
                          width: abs(end.x - start.x),
                          height: abs(end.y - start.y))
        
        let path = NSBezierPath(rect: rect)
        path.lineWidth = annotation.lineWidth
        NSColor(annotation.color).setStroke()
        path.stroke()
    }
    
    private func drawArrow(_ annotation: Annotation, in context: NSGraphicsContext) {
        guard annotation.points.count >= 2 else { return }
        let start = annotation.points[0]
        let end = annotation.points[1]
        
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = annotation.lineWidth
        NSColor(annotation.color).setStroke()
        path.stroke()
        
        // 箭头头部
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 12
        let arrowAngle: CGFloat = .pi / 6
        
        let arrow1 = CGPoint(x: end.x - arrowLength * cos(angle - arrowAngle),
                             y: end.y - arrowLength * sin(angle - arrowAngle))
        let arrow2 = CGPoint(x: end.x - arrowLength * cos(angle + arrowAngle),
                             y: end.y - arrowLength * sin(angle + arrowAngle))
        
        let arrowPath = NSBezierPath()
        arrowPath.move(to: end)
        arrowPath.line(to: arrow1)
        arrowPath.move(to: end)
        arrowPath.line(to: arrow2)
        arrowPath.lineWidth = annotation.lineWidth
        arrowPath.stroke()
    }
    
    private func drawFreehand(_ annotation: Annotation, in context: NSGraphicsContext) {
        guard annotation.points.count >= 2 else { return }
        
        let path = NSBezierPath()
        path.move(to: annotation.points[0])
        for point in annotation.points.dropFirst() {
            path.line(to: point)
        }
        path.lineWidth = annotation.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor(annotation.color).setStroke()
        path.stroke()
    }
    
    private func drawText(_ annotation: Annotation, in context: NSGraphicsContext) {
        guard let text = annotation.text, let position = annotation.points.first else { return }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: annotation.color
        ]
        let nsString = text as NSString
        nsString.draw(at: position, withAttributes: attributes)
    }
    
    private func drawMosaic(_ annotation: Annotation, in context: NSGraphicsContext) {
        guard annotation.points.count >= 2 else { return }
        let start = annotation.points[0]
        let end = annotation.points[1]
        let rect = CGRect(x: min(start.x, end.x),
                          y: min(start.y, end.y),
                          width: abs(end.x - start.x),
                          height: abs(end.y - start.y))
        
        // 简单的马赛克效果：用半透明矩形填充
        let mosaicSize: CGFloat = 10
        NSColor.white.setFill()
        
        var x = rect.minX
        while x < rect.maxX {
            var y = rect.minY
            while y < rect.maxY {
                let blockRect = CGRect(x: x, y: y,
                                       width: min(mosaicSize, rect.maxX - x),
                                       height: min(mosaicSize, rect.maxY - y))
                NSBezierPath(rect: blockRect).fill()
                y += mosaicSize
            }
            x += mosaicSize
        }
    }
    
    // MARK: - Toast
    
    func showToast(_ message: String) {
        toastMessage = message
        isShowingToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isShowingToast = false
            self.toastMessage = nil
        }
    }
    
    // MARK: - 关闭
    
    func closeOverlay() {
        isShowingOverlay = false
        state = .idle
        selection = .zero
        capturedImage = nil
        annotationEngine.clearAll()
        currentTool = nil
    }
    
    // MARK: - 取消
    
    func cancel() {
        closeOverlay()
    }
}

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
    
    // MARK: - 覆盖层控制回调（由 ScreenshotModule 设置）
    var onHideOverlay: (() -> Void)?
    var onShowOverlay: (() -> Void)?
    
    // MARK: - 选区调整相关
    enum ResizeHandle: CaseIterable {
        case none, nw, n, ne, e, se, s, sw, w
        
        static var allCases: [ResizeHandle] {
            return [.nw, .n, .ne, .e, .se, .s, .sw, .w]
        }
    }
    @Published var activeHandle: ResizeHandle = .none
    @Published var isDragging = false
    
    // MARK: - 安全超时
    private var safetyTimer: Timer?
    private let safetyTimeout: TimeInterval = 300 // 5分钟超时自动关闭
    
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
        
        // 启动安全超时
        startSafetyTimer()
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
        
        // 先隐藏覆盖层，避免遮挡保存对话框
        onHideOverlay?()
        
        if let url = ExportService.showSavePanel(image: image, defaultDirectory: config.saveDirectory) {
            showToast("已保存到 \(url.lastPathComponent)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.closeOverlay()
            }
        } else {
            // 用户取消了保存，重新显示覆盖层
            onShowOverlay?()
        }
    }
    
    // MARK: - 渲染
    
    /// 渲染最终图片（根据选区裁剪 + 标注）
    func renderFinalImage() -> NSImage? {
        guard let cgImage = capturedImage else { return nil }
        
        // 确保选区有效
        guard selection.width > 0 && selection.height > 0 else {
            print("[ScreenshotViewModel] ❌ Invalid selection: \(selection)")
            return nil
        }
        
        // 将选区坐标从 SwiftUI 坐标系（左上角原点）转换为 CGImage 坐标系（左下角原点）
        let screenHeight = CGFloat(cgImage.height)
        let scaleX = CGFloat(cgImage.width) / NSScreen.main!.frame.width
        let scaleY = CGFloat(cgImage.height) / NSScreen.main!.frame.height
        
        // 转换选区坐标到图片坐标系
        let imageSelection = CGRect(
            x: selection.origin.x * scaleX,
            y: (screenHeight - (selection.origin.y + selection.height) * scaleY),
            width: selection.width * scaleX,
            height: selection.height * scaleY
        )
        
        print("[ScreenshotViewModel] Selection in SwiftUI coords: \(selection)")
        print("[ScreenshotViewModel] Selection in image coords: \(imageSelection)")
        print("[ScreenshotViewModel] Image size: \(cgImage.width) x \(cgImage.height)")
        
        // 裁剪图片到选区
        guard let croppedCGImage = cgImage.cropping(to: imageSelection) else {
            print("[ScreenshotViewModel] ❌ Failed to crop image")
            return nil
        }
        
        let croppedImage = ExportService.nsImage(from: croppedCGImage)
        let croppedSize = NSSize(width: croppedCGImage.width, height: croppedCGImage.height)
        
        // 创建位图上下文绘制裁剪后的图片 + 标注
        let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                          pixelsWide: Int(croppedSize.width),
                                          pixelsHigh: Int(croppedSize.height),
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
        
        // 绘制裁剪后的图片
        croppedImage.draw(in: NSRect(origin: .zero, size: croppedSize))
        
        // 绘制标注（需要调整坐标，因为原点变了）
        drawAnnotationsForCroppedImage(in: context, imageSize: croppedSize)
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let finalImage = bitmapRep.cgImage else { return nil }
        return ExportService.nsImage(from: finalImage)
    }
    
    /// 绘制标注到裁剪后的图片
    private func drawAnnotationsForCroppedImage(in context: NSGraphicsContext, imageSize: NSSize) {
        guard let cgImage = capturedImage else { return }
        
        let scaleX = CGFloat(cgImage.width) / NSScreen.main!.frame.width
        let scaleY = CGFloat(cgImage.height) / NSScreen.main!.frame.height
        
        // 计算选区在图片坐标系中的位置
        let screenHeight = CGFloat(cgImage.height)
        let imageSelection = CGRect(
            x: selection.origin.x * scaleX,
            y: (screenHeight - (selection.origin.y + selection.height) * scaleY),
            width: selection.width * scaleX,
            height: selection.height * scaleY
        )
        
        for annotation in annotationEngine.annotations {
            // 转换标注点坐标到裁剪后的图片坐标系
            let convertedPoints = annotation.points.map { point -> CGPoint in
                let imagePoint = CGPoint(
                    x: point.x * scaleX,
                    y: screenHeight - point.y * scaleY
                )
                // 相对于裁剪区域的坐标
                return CGPoint(
                    x: imagePoint.x - imageSelection.origin.x,
                    y: imagePoint.y - imageSelection.origin.y
                )
            }
            
            switch annotation.type {
            case .rect:
                drawRectWithPoints(convertedPoints, color: annotation.color, lineWidth: annotation.lineWidth)
            case .arrow:
                drawArrowWithPoints(convertedPoints, color: annotation.color, lineWidth: annotation.lineWidth)
            case .freehand:
                drawFreehandWithPoints(convertedPoints, color: annotation.color, lineWidth: annotation.lineWidth)
            case .text:
                if let text = annotation.text, let position = convertedPoints.first {
                    drawTextAtPoint(text, position: position, color: annotation.color)
                }
            case .mosaic:
                drawMosaicWithPoints(convertedPoints)
            }
        }
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
    
    // MARK: - 标注绘制辅助方法（用于裁剪后的图片）
    
    private func drawRectWithPoints(_ points: [CGPoint], color: Color, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        let start = points[0]
        let end = points[1]
        let rect = CGRect(x: min(start.x, end.x),
                          y: min(start.y, end.y),
                          width: abs(end.x - start.x),
                          height: abs(end.y - start.y))
        
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        NSColor(color).setStroke()
        path.stroke()
    }
    
    private func drawArrowWithPoints(_ points: [CGPoint], color: Color, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        let start = points[0]
        let end = points[1]
        
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = lineWidth
        NSColor(color).setStroke()
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
        arrowPath.lineWidth = lineWidth
        arrowPath.stroke()
    }
    
    private func drawFreehandWithPoints(_ points: [CGPoint], color: Color, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        
        let path = NSBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor(color).setStroke()
        path.stroke()
    }
    
    private func drawTextAtPoint(_ text: String, position: CGPoint, color: Color) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor(color)
        ]
        let nsString = text as NSString
        nsString.draw(at: position, withAttributes: attributes)
    }
    
    private func drawMosaicWithPoints(_ points: [CGPoint]) {
        guard points.count >= 2 else { return }
        let start = points[0]
        let end = points[1]
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
        // 取消安全超时
        cancelSafetyTimer()
        
        isShowingOverlay = false
        state = .idle
        selection = .zero
        capturedImage = nil
        annotationEngine.clearAll()
        currentTool = nil
    }
    
    // MARK: - 取消
    
    func cancel() {
        print("[ScreenshotViewModel] Cancel called")
        closeOverlay()
    }
    
    // MARK: - 安全超时机制
    
    private func startSafetyTimer() {
        cancelSafetyTimer()
        safetyTimer = Timer.scheduledTimer(withTimeInterval: safetyTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                print("[ScreenshotViewModel] ⚠️ Safety timeout reached, force closing overlay")
                self?.closeOverlay()
            }
        }
    }
    
    private func cancelSafetyTimer() {
        safetyTimer?.invalidate()
        safetyTimer = nil
    }
}

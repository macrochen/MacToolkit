import SwiftUI
import AppKit

/// 标注绘制视图 - 处理鼠标事件创建标注
struct AnnotationDrawView: NSViewRepresentable {
    @ObservedObject var viewModel: ScreenshotViewModel
    let selectionRect: CGRect
    
    func makeNSView(context: Context) -> AnnotationNSView {
        let view = AnnotationNSView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: AnnotationNSView, context: Context) {
        // NSView 的 frame 已经由 SwiftUI 的 .frame() 限制
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    // MARK: - Coordinator
    
    @MainActor
    class Coordinator: NSObject, AnnotationNSViewDelegate {
        let viewModel: ScreenshotViewModel
        private var currentPoints: [CGPoint] = []
        private var isDrawing = false
        
        init(viewModel: ScreenshotViewModel) {
            self.viewModel = viewModel
        }
        
        /// 将 NSView 坐标转换为 SwiftUI 坐标
        /// NSView: 左下角原点，Y 向上
        /// SwiftUI: 左上角原点，Y 向下
        private func convertToSwiftUI(_ point: CGPoint, viewHeight: CGFloat) -> CGPoint {
            CGPoint(x: point.x, y: viewHeight - point.y)
        }
        
        func didMouseDown(at point: CGPoint, viewHeight: CGFloat) {
            guard let tool = viewModel.currentTool else { return }
            
            let swiftUIPoint = convertToSwiftUI(point, viewHeight: viewHeight)
            
            switch tool {
            case .rect, .arrow, .mosaic, .freehand:
                currentPoints = [swiftUIPoint]
                isDrawing = true
            case .text:
                viewModel.beginTextAnnotation(at: swiftUIPoint)
            }
        }
        
        func didMouseDragged(to point: CGPoint, viewHeight: CGFloat) {
            guard isDrawing else { return }
            
            let swiftUIPoint = convertToSwiftUI(point, viewHeight: viewHeight)
            
            switch viewModel.currentTool {
            case .rect, .arrow, .mosaic:
                if currentPoints.count >= 1 {
                    currentPoints = [currentPoints[0], swiftUIPoint]
                }
                
            case .freehand:
                currentPoints.append(swiftUIPoint)
                
            default:
                break
            }
            
            // 触发重绘
            viewModel.annotationPreviewPoints = currentPoints
        }
        
        func didMouseUp(at point: CGPoint, viewHeight: CGFloat) {
            guard isDrawing, let tool = viewModel.currentTool else { return }
            
            let swiftUIPoint = convertToSwiftUI(point, viewHeight: viewHeight)
            
            switch tool {
            case .rect:
                if currentPoints.count >= 2 {
                    let annotation = viewModel.annotationEngine.createRect(
                        start: currentPoints[0],
                        end: swiftUIPoint
                    )
                    viewModel.annotationEngine.add(annotation)
                }
                
            case .arrow:
                if currentPoints.count >= 2 {
                    let annotation = viewModel.annotationEngine.createArrow(
                        start: currentPoints[0],
                        end: swiftUIPoint
                    )
                    viewModel.annotationEngine.add(annotation)
                }
                
            case .freehand:
                if currentPoints.count >= 2 {
                    let annotation = viewModel.annotationEngine.createFreehand(points: currentPoints)
                    viewModel.annotationEngine.add(annotation)
                }
                
            case .text:
                break

            case .mosaic:
                if currentPoints.count >= 2 {
                    let annotation = viewModel.annotationEngine.createMosaic(
                        start: currentPoints[0],
                        end: swiftUIPoint
                    )
                    viewModel.annotationEngine.add(annotation)
                }
            }
            
            // 重置状态
            currentPoints = []
            isDrawing = false
            viewModel.annotationPreviewPoints = []
        }

    }
}

// MARK: - NSView 实现

@MainActor
protocol AnnotationNSViewDelegate: AnyObject {
    func didMouseDown(at point: CGPoint, viewHeight: CGFloat)
    func didMouseDragged(to point: CGPoint, viewHeight: CGFloat)
    func didMouseUp(at point: CGPoint, viewHeight: CGFloat)
}

class AnnotationNSView: NSView {
    weak var delegate: AnnotationNSViewDelegate?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.didMouseDown(at: point, viewHeight: bounds.height)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.didMouseDragged(to: point, viewHeight: bounds.height)
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.didMouseUp(at: point, viewHeight: bounds.height)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // 不绘制任何内容，标注由 SwiftUI 层渲染
    }
}

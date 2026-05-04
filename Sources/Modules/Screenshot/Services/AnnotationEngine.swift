import SwiftUI

/// 标注引擎，管理标注数据
class AnnotationEngine: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentColor: Color = .red
    @Published var currentLineWidth: CGFloat = 2
    
    /// 添加标注
    func add(_ annotation: Annotation) {
        annotations.append(annotation)
    }
    
    /// 撤销最后一个标注
    func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
    }
    
    /// 清空所有标注
    func clearAll() {
        annotations.removeAll()
    }
    
    /// 是否有标注
    var hasAnnotations: Bool {
        !annotations.isEmpty
    }
    
    // MARK: - 创建标注
    
    /// 创建矩形标注
    func createRect(start: CGPoint, end: CGPoint) -> Annotation {
        Annotation(type: .rect, points: [start, end], color: currentColor, lineWidth: currentLineWidth)
    }
    
    /// 创建箭头标注
    func createArrow(start: CGPoint, end: CGPoint) -> Annotation {
        Annotation(type: .arrow, points: [start, end], color: currentColor, lineWidth: currentLineWidth)
    }
    
    /// 创建画笔标注
    func createFreehand(points: [CGPoint]) -> Annotation {
        Annotation(type: .freehand, points: points, color: currentColor, lineWidth: currentLineWidth)
    }
    
    /// 创建文字标注
    func createText(position: CGPoint, text: String) -> Annotation {
        Annotation(type: .text, points: [position], text: text, color: currentColor, lineWidth: currentLineWidth)
    }
    
    /// 创建马赛克标注
    func createMosaic(start: CGPoint, end: CGPoint) -> Annotation {
        Annotation(type: .mosaic, points: [start, end], color: .clear, lineWidth: 0)
    }
}

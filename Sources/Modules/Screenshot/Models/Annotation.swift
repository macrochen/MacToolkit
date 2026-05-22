import SwiftUI

/// 标注类型
enum AnnotationType: String, CaseIterable, Identifiable {
    case rect
    case arrow
    case freehand
    case text
    case mosaic
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .rect: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .freehand: return "pencil"
        case .text: return "textformat"
        case .mosaic: return "square.grid.3x3"
        }
    }
    
    var name: String {
        switch self {
        case .rect: return "矩形"
        case .arrow: return "箭头"
        case .freehand: return "画笔"
        case .text: return "文字"
        case .mosaic: return "马赛克"
        }
    }
    
    var shortcut: String {
        switch self {
        case .rect: return "R"
        case .arrow: return "A"
        case .freehand: return "P"
        case .text: return "T"
        case .mosaic: return "M"
        }
    }
}

/// 标注数据
struct Annotation: Identifiable {
    let id: UUID
    let type: AnnotationType
    var points: [CGPoint]
    var text: String?
    var color: Color
    var lineWidth: CGFloat
    
    init(type: AnnotationType, points: [CGPoint], text: String? = nil, color: Color = .red, lineWidth: CGFloat = 2) {
        self.id = UUID()
        self.type = type
        self.points = points
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
    }
}

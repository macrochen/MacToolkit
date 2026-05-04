import Foundation
import CoreGraphics

/// 支持的鼠标输入类型
enum MouseInputType: String, Codable, CaseIterable, Identifiable {
    case scrollUp
    case scrollDown
    case scrollLeft
    case scrollRight
    case middleButton
    case button4 // 侧键 Back
    case button5 // 侧键 Forward
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .scrollUp: return "滚轮向上"
        case .scrollDown: return "滚轮向下"
        case .scrollLeft: return "滚轮向左 (Tilt Left)"
        case .scrollRight: return "滚轮向右 (Tilt Right)"
        case .middleButton: return "中键 (Middle Btn)"
        case .button4: return "侧键 4 (Back)"
        case .button5: return "侧键 5 (Forward)"
        }
    }
}

/// 单个映射规则
struct KeyMapping: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var inputType: MouseInputType
    
    // 目标快捷键
    var targetKeyCode: CGKeyCode
    var targetModifiers: UInt64 // 存储 CGEventFlags.rawValue
    
    // 用于 UI 显示的快捷键描述（可选，避免频繁计算）
    var targetDescription: String?
}

/// 针对特定 App 的配置集合
struct AppConfig: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var bundleId: String? // nil 表示 "Global Default"
    var appName: String   // 显示名称，如 "Google Chrome"
    var iconPath: String? // 可选：存储图标路径
    var mappings: [KeyMapping] = []
    
    static let globalDefault = AppConfig(bundleId: nil, appName: "全局默认 (Global)", mappings: [])
}

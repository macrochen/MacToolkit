import Foundation

/// 触摸板手势类型
enum TouchpadGestureType: String, Codable, CaseIterable, Identifiable {
    case threeFingerTap    // 三指点击（通常映射为中键）
    case fourFingerTap     // 四指点击
    case threeFingerSwipeUp
    case threeFingerSwipeDown
    case threeFingerSwipeLeft
    case threeFingerSwipeRight
    case fourFingerSwipeUp
    case fourFingerSwipeDown
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .threeFingerTap: return "三指点击"
        case .fourFingerTap: return "四指点击"
        case .threeFingerSwipeUp: return "三指上滑"
        case .threeFingerSwipeDown: return "三指下滑"
        case .threeFingerSwipeLeft: return "三指左滑"
        case .threeFingerSwipeRight: return "三指右滑"
        case .fourFingerSwipeUp: return "四指上滑"
        case .fourFingerSwipeDown: return "四指下滑"
        }
    }
    
    var icon: String {
        switch self {
        case .threeFingerTap: return "hand.tap"
        case .fourFingerTap: return "hand.tap"
        case .threeFingerSwipeUp, .threeFingerSwipeDown, .threeFingerSwipeLeft, .threeFingerSwipeRight: return "hand.draw"
        case .fourFingerSwipeUp, .fourFingerSwipeDown: return "hand.draw"
        }
    }
}

/// 目标动作类型
enum GestureActionType: String, Codable, CaseIterable, Identifiable {
    case cmdClick          // Cmd + 点击（新标签页打开）
    case cmdT              // Cmd + T（新建标签页）
    case cmdW              // Cmd + W（关闭标签页）
    case cmdShiftT         // Cmd + Shift + T（恢复关闭的标签页）
    case cmdLeftBracket    // Cmd + [（返回上一页）
    case cmdRightBracket   // Cmd + ]（前进下一页）
    case custom            // 自定义快捷键
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cmdClick: return "Cmd + 点击"
        case .cmdT: return "Cmd + T (新建标签页)"
        case .cmdW: return "Cmd + W (关闭标签页)"
        case .cmdShiftT: return "Cmd + Shift + T (恢复标签页)"
        case .cmdLeftBracket: return "Cmd + [ (返回)"
        case .cmdRightBracket: return "Cmd + ] (前进)"
        case .custom: return "自定义快捷键"
        }
    }
    
    var keyDescription: String {
        switch self {
        case .cmdClick: return "⌘ + Click"
        case .cmdT: return "⌘ T"
        case .cmdW: return "⌘ W"
        case .cmdShiftT: return "⌘ ⇧ T"
        case .cmdLeftBracket: return "⌘ ["
        case .cmdRightBracket: return "⌘ ]"
        case .custom: return "自定义"
        }
    }
}

/// 单个手势映射规则
struct GestureMapping: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var gestureType: TouchpadGestureType
    var actionType: GestureActionType
    
    // 自定义快捷键（当 actionType == .custom 时使用）
    var customKeyCode: UInt16 = 0
    var customModifiers: UInt64 = 0
    var customDescription: String? = nil
    
    // 是否在当前应用下生效（相对于应用特定配置）
    var isEnabled: Bool = true
}

/// 针对特定 App 的手势配置集合
struct GestureAppConfig: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var bundleId: String?  // nil 表示 "全局默认"
    var appName: String
    var mappings: [GestureMapping] = []
    
    static let globalDefault = GestureAppConfig(bundleId: nil, appName: "全局默认", mappings: [])
}

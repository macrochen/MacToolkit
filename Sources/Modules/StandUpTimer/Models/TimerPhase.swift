import Foundation

enum TimerPhase: String, CaseIterable {
    case sitting   = "sitting"
    case standing  = "standing"
    case moving    = "moving"
    
    var icon: String {
        switch self {
        case .sitting:  return "🪑"
        case .standing: return "🧍"
        case .moving:   return "🚶"
        }
    }
    
    var label: String {
        switch self {
        case .sitting:  return "坐着"
        case .standing: return "站立"
        case .moving:   return "活动"
        }
    }
    
    var alertMessage: String {
        switch self {
        case .sitting:  return "可以坐下了，继续加油 🪑"
        case .standing: return "该站起来了！久坐伤身 🧍"
        case .moving:   return "活动一下，走两步 🚶"
        }
    }
    
    var next: TimerPhase {
        switch self {
        case .sitting:  return .standing
        case .standing: return .moving
        case .moving:   return .sitting
        }
    }
}

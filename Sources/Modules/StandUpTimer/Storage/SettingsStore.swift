import Foundation

class SettingsStore {
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let sittingDuration = "sittingDuration"
        static let standingDuration = "standingDuration"
        static let movingDuration = "movingDuration"
        static let catDisplaySeconds = "catDisplaySeconds"
    }
    
    // 默认值：坐20分钟，站8分钟，活动2分钟
    var sittingDuration: Int {
        get { defaults.object(forKey: Keys.sittingDuration) as? Int ?? 20 }
        set { defaults.set(newValue, forKey: Keys.sittingDuration) }
    }
    
    var standingDuration: Int {
        get { defaults.object(forKey: Keys.standingDuration) as? Int ?? 8 }
        set { defaults.set(newValue, forKey: Keys.standingDuration) }
    }
    
    var movingDuration: Int {
        get { defaults.object(forKey: Keys.movingDuration) as? Int ?? 2 }
        set { defaults.set(newValue, forKey: Keys.movingDuration) }
    }
    
    // 猫咪显示时长（秒）
    var catDisplaySeconds: Int {
        get { defaults.object(forKey: Keys.catDisplaySeconds) as? Int ?? 10 }
        set { defaults.set(newValue, forKey: Keys.catDisplaySeconds) }
    }
    
    func duration(for phase: TimerPhase) -> Int {
        let minutes: Int
        switch phase {
        case .sitting:  minutes = sittingDuration
        case .standing: minutes = standingDuration
        case .moving:   minutes = movingDuration
        }
        return minutes * 60  // 转成秒
    }
    
    func reset() {
        sittingDuration = 20
        standingDuration = 8
        movingDuration = 2
        catDisplaySeconds = 10
    }
}

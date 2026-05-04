import SwiftUI
import Carbon.HIToolbox

/// 截图配置
struct CaptureConfig {
    /// 默认保存目录
    var saveDirectory: URL
    
    /// 快捷键
    var hotkey: HotkeyConfig
    
    init() {
        // 从 UserDefaults 加载保存目录
        if let savedPath = UserDefaults.standard.string(forKey: "screenshot_save_directory") {
            self.saveDirectory = URL(fileURLWithPath: savedPath)
        } else {
            self.saveDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        
        // 从 UserDefaults 加载快捷键配置
        let savedKeyCode = UInt32(UserDefaults.standard.integer(forKey: "screenshot_hotkey_keycode"))
        let savedModifiersRaw = UInt(UserDefaults.standard.integer(forKey: "screenshot_hotkey_modifiers"))
        
        if savedKeyCode > 0 && savedModifiersRaw > 0 {
            self.hotkey = HotkeyConfig(keyCode: savedKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: savedModifiersRaw))
        } else {
            self.hotkey = HotkeyConfig()
        }
    }
    
    /// 保存到 UserDefaults
    func save() {
        UserDefaults.standard.set(saveDirectory.path, forKey: "screenshot_save_directory")
        UserDefaults.standard.set(Int(hotkey.keyCode), forKey: "screenshot_hotkey_keycode")
        UserDefaults.standard.set(Int(hotkey.modifiers.rawValue), forKey: "screenshot_hotkey_modifiers")
    }
}

/// 快捷键配置
struct HotkeyConfig {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags
    
    init() {
        // 默认 ⌘+Shift+A
        self.keyCode = 0 // A key
        self.modifiers = [.command, .shift]
    }
    
    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        
        if keyCode > 0 {
            parts.append(HotkeyConfig.keyCodeToString(keyCode))
        }
        
        return parts.isEmpty ? "未设置" : parts.joined()
    }
    
    /// 转换为 Carbon 修饰键
    var carbonModifiers: UInt32 {
        var mods: UInt32 = 0
        if modifiers.contains(.command) { mods |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { mods |= UInt32(shiftKey) }
        if modifiers.contains(.option) { mods |= UInt32(optionKey) }
        if modifiers.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
    
    /// keyCode 转字符串
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 50: return "`"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 53: return "⎋"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "[\(keyCode)]"
        }
    }
}

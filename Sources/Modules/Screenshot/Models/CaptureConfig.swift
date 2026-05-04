import SwiftUI

/// 截图配置
struct CaptureConfig {
    /// 默认保存目录
    var saveDirectory: URL
    
    /// 快捷键
    var hotkey: HotkeyConfig
    
    init() {
        // 默认保存到 ~/Downloads
        self.saveDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        self.hotkey = HotkeyConfig()
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
    
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        parts.append("A")
        return parts.joined()
    }
}

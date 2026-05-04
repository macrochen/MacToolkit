import AppKit
import Foundation

@MainActor
final class ShortcutManager: ObservableObject {
    @Published private(set) var statusMessage = "正在准备全局快捷键。"

    private var snippets: [Snippet] = []
    private weak var permissionService: PermissionService?
    private weak var typingService: TypingService?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func configure(with snippets: [Snippet], permissionService: PermissionService, typingService: TypingService) {
        self.snippets = snippets
        self.permissionService = permissionService
        self.typingService = typingService
        print("[ShortcutManager] Configuring with \(snippets.count) snippets")
        registerHotKeys()
    }

    func triggerSnippet(id: UUID) {
        guard
            let snippet = snippets.first(where: { $0.id == id && $0.isEnabled }),
            let permissionService,
            let typingService
        else {
            statusMessage = "找不到可触发的短语。"
            return
        }

        typingService.send(snippet: snippet, permissionService: permissionService)
        statusMessage = "已触发快捷短语: \(snippet.title)"
    }

    private func registerHotKeys() {
        print("[ShortcutManager] Registering hotkeys...")

        // 先移除旧的 tap
        removeEventTap()

        let enabledSnippets = snippets.filter(\.isEnabled)
        print("[ShortcutManager] Enabled snippets: \(enabledSnippets.count)")

        guard !enabledSnippets.isEmpty else {
            statusMessage = "没有启用的快捷短语。"
            return
        }

        // 检查重复快捷键
        let duplicateDisplays = duplicates(in: enabledSnippets.map(\.shortcut.displayText))
        guard duplicateDisplays.isEmpty else {
            statusMessage = "有重复快捷键: \(duplicateDisplays.joined(separator: "、"))"
            print("[ShortcutManager] Duplicate hotkeys found: \(duplicateDisplays)")
            return
        }

        for snippet in enabledSnippets {
            print("[ShortcutManager] Registering: \(snippet.shortcut.displayText)")
        }

        // 使用 CGEventTap 拦截键盘事件
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let eventMask = (1 << CGEventFlags.maskCommand.rawValue) != 0
            ? CGEventMask(1 << CGEventType.keyDown.rawValue)
            : CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }

                let manager = Unmanaged<ShortcutManager>.fromOpaque(refcon).takeUnretainedValue()

                // 只处理 keyDown 事件
                if type == .keyDown {
                    let flags = event.flags
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                    if manager.handleKeyEvent(keyCode: keyCode, flags: flags) {
                        // 匹配到快捷键，吞噬事件
                        return nil
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        ) else {
            print("[ShortcutManager] ❌ Failed to create event tap")
            statusMessage = "无法创建事件监听，请检查辅助功能权限。"
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        statusMessage = "已注册 \(enabledSnippets.count) 个全局快捷键。"
        print("[ShortcutManager] \(statusMessage)")
    }

    private func handleKeyEvent(keyCode: Int64, flags: CGEventFlags) -> Bool {
        // 将 CGEventFlags 转换为 NSEvent.ModifierFlags 进行比较
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))

        for snippet in snippets where snippet.isEnabled {
            guard let expectedKeyCode = Self.keyCode(for: snippet.shortcut.key) else { continue }
            let expectedModifiers = Self.modifierFlags(for: snippet.shortcut)

            if Int64(expectedKeyCode) == keyCode && nsFlags.contains(expectedModifiers) {
                // 检查修饰键是否完全匹配（不包含其他修饰键）
                let relevantFlags = nsFlags.intersection([.command, .option, .control, .shift])
                if relevantFlags == expectedModifiers {
                    print("[ShortcutManager] Matched: \(snippet.shortcut.displayText) -> \(snippet.title)")
                    // 在主线程触发
                    DispatchQueue.main.async { [weak self] in
                        self?.triggerSnippet(id: snippet.id)
                    }
                    return true
                }
            }
        }
        return false
    }

    private func removeEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    nonisolated deinit {
        // Cleanup is done in removeEventTap()
    }

    private func duplicates(in items: [String]) -> [String] {
        var seen = Set<String>()
        var repeated = Set<String>()

        for item in items {
            if !seen.insert(item).inserted {
                repeated.insert(item)
            }
        }

        return repeated.sorted()
    }

    private static func modifierFlags(for shortcut: Shortcut) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        for modifier in shortcut.modifiers {
            switch modifier {
            case .command:
                flags.insert(NSEvent.ModifierFlags.command)
            case .option:
                flags.insert(NSEvent.ModifierFlags.option)
            case .control:
                flags.insert(NSEvent.ModifierFlags.control)
            case .shift:
                flags.insert(NSEvent.ModifierFlags.shift)
            }
        }

        return flags
    }

    private static func keyCode(for key: String) -> UInt32? {
        switch key.uppercased() {
        case "1": 18
        case "2": 19
        case "3": 20
        case "4": 21
        case "5": 23
        case "6": 22
        case "7": 26
        case "8": 28
        case "9": 25
        case "0": 29
        case "A": 0
        case "B": 11
        case "C": 8
        case "D": 2
        case "E": 14
        case "F": 3
        case "G": 5
        case "H": 4
        case "I": 34
        case "J": 38
        case "K": 40
        case "L": 37
        case "M": 46
        case "N": 45
        case "O": 31
        case "P": 35
        case "Q": 12
        case "R": 15
        case "S": 1
        case "T": 17
        case "U": 32
        case "V": 9
        case "W": 13
        case "X": 7
        case "Y": 16
        case "Z": 6
        default: nil
        }
    }
}

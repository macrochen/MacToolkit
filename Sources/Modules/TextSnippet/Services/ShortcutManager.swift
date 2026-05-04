import Carbon
import Foundation

@MainActor
final class ShortcutManager: ObservableObject {
    @Published private(set) var statusMessage = "正在准备全局快捷键。"

    private var snippets: [Snippet] = []
    private weak var permissionService: PermissionService?
    private weak var typingService: TypingService?
    private var hotKeyRefs: [UUID: EventHotKeyRef] = [:]
    private var hotKeyLookup: [UInt32: UUID] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?
    private let signature = OSType(0x54454E54)

    init() {
        installEventHandlerIfNeeded()
    }

    func configure(with snippets: [Snippet], permissionService: PermissionService, typingService: TypingService) {
        self.snippets = snippets
        self.permissionService = permissionService
        self.typingService = typingService
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

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard
                    let userData,
                    let event
                else {
                    return noErr
                }

                let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return status }
                manager.handleHotKey(carbonID: hotKeyID.id)
                return noErr
            },
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )
    }

    private func registerHotKeys() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }

        hotKeyRefs.removeAll()
        hotKeyLookup.removeAll()
        nextHotKeyID = 1

        let enabledSnippets = snippets.filter(\.isEnabled)
        let duplicateDisplays = duplicates(in: enabledSnippets.map(\.shortcut.displayText))
        guard duplicateDisplays.isEmpty else {
            statusMessage = "有重复快捷键: \(duplicateDisplays.joined(separator: "、"))"
            return
        }

        var failedDisplays: [String] = []

        for snippet in enabledSnippets {
            guard
                let keyCode = Self.keyCode(for: snippet.shortcut.key),
                let modifiers = Self.carbonModifiers(for: snippet.shortcut)
            else {
                failedDisplays.append(snippet.shortcut.displayText)
                continue
            }

            var hotKeyRef: EventHotKeyRef?
            let carbonID = EventHotKeyID(signature: signature, id: nextHotKeyID)
            let registerStatus = RegisterEventHotKey(
                UInt32(keyCode),
                modifiers,
                carbonID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if registerStatus == noErr, let hotKeyRef {
                hotKeyRefs[snippet.id] = hotKeyRef
                hotKeyLookup[nextHotKeyID] = snippet.id
                nextHotKeyID += 1
            } else {
                failedDisplays.append(snippet.shortcut.displayText)
            }
        }

        if failedDisplays.isEmpty {
            statusMessage = "已注册 \(hotKeyRefs.count) 个全局快捷键。"
        } else {
            statusMessage = "已注册 \(hotKeyRefs.count) 个快捷键，失败: \(failedDisplays.joined(separator: "、"))"
        }
    }

    private func handleHotKey(carbonID: UInt32) {
        guard let snippetID = hotKeyLookup[carbonID] else { return }
        triggerSnippet(id: snippetID)
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

    private static func carbonModifiers(for shortcut: Shortcut) -> UInt32? {
        var flags: UInt32 = 0

        for modifier in shortcut.modifiers {
            switch modifier {
            case .command:
                flags |= UInt32(cmdKey)
            case .option:
                flags |= UInt32(optionKey)
            case .control:
                flags |= UInt32(controlKey)
            case .shift:
                flags |= UInt32(shiftKey)
            }
        }

        return flags == 0 ? nil : flags
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

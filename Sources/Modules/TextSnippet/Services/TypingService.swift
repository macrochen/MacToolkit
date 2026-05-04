import AppKit
@preconcurrency import ApplicationServices
import Foundation

enum PasteStep: Equatable {
    case paste(String)
    case submitReturn
    case clearClipboard
}

@MainActor
final class TypingService: ObservableObject {
    @Published private(set) var statusMessage = "等待快捷键触发。"
    @Published private(set) var lastTargetName = "未记录目标应用"

    nonisolated static let targetActivationDelayMilliseconds = 180
    nonisolated static let pasteCompletionDelayMilliseconds = 250
    nonisolated static let returnKeyUpDelayMilliseconds = 20

    private var lastExternalApp: NSRunningApplication?
    private let notificationCenter = NSWorkspace.shared.notificationCenter

    init() {
        observeActivatedApplications()
    }

    func send(snippet: Snippet, permissionService: PermissionService) {
        print("[TypingService] send called for: \(snippet.title)")
        permissionService.refresh()

        guard permissionService.isAccessibilityGranted else {
            statusMessage = "缺少辅助功能权限，无法发送文本。"
            print("[TypingService] ❌ No accessibility permission")
            return
        }
        print("[TypingService] ✅ Accessibility permission granted")

        guard let target = currentTargetApplication() else {
            statusMessage = "请先切到目标应用一次，再使用快捷键。"
            print("[TypingService] ❌ No target application")
            return
        }
        print("[TypingService] ✅ Target app: \(target.localizedName ?? "unknown")")

        statusMessage = "正在发送到 \(target.localizedName ?? "目标应用")..."
        lastExternalApp = target
        lastTargetName = target.localizedName ?? "未知应用"

        Task { @MainActor in
            print("[TypingService] Waiting for modifiers to clear...")
            await waitForHotKeyModifiersToClear()
            print("[TypingService] Activating target...")
            target.activate()
            try? await Task.sleep(for: .milliseconds(Self.targetActivationDelayMilliseconds))
            print("[TypingService] Pasting content...")
            await pasteAndSubmit(snippet.content, autoEnter: snippet.autoEnter)
            statusMessage = "已发送: \(snippet.title)"
            print("[TypingService] ✅ Done")
        }
    }

    private func observeActivatedApplications() {
        notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastExternalApp = app
                self.lastTargetName = app.localizedName ?? "未知应用"
            }
        }
    }

    private func currentTargetApplication() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            return frontmost
        }

        return lastExternalApp
    }

    nonisolated static func pastePlan(for text: String, autoEnter: Bool) -> [PasteStep] {
        var steps: [PasteStep] = [.paste(text)]
        if autoEnter {
            steps.append(.submitReturn)
        }
        steps.append(.clearClipboard)
        return steps
    }

    nonisolated static func hotKeyModifierFlagsArePressed(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskControl)
            || flags.contains(.maskShift)
    }

    private func waitForHotKeyModifiersToClear() async {
        while Self.hotKeyModifierFlagsArePressed(CGEventSource.flagsState(.combinedSessionState)) {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func pasteAndSubmit(_ text: String, autoEnter: Bool) async {
        for step in Self.pastePlan(for: text, autoEnter: autoEnter) {
            switch step {
            case .paste(let text):
                paste(text)
                try? await Task.sleep(for: .milliseconds(Self.pasteCompletionDelayMilliseconds))
            case .submitReturn:
                await pressReturn()
            case .clearClipboard:
                NSPasteboard.general.clearContents()
            }
        }
    }

    private func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }

    private func pressReturn(modifiers: CGEventFlags = []) async {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        down?.flags = modifiers
        down?.post(tap: .cghidEventTap)

        try? await Task.sleep(for: .milliseconds(Self.returnKeyUpDelayMilliseconds))

        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        up?.flags = modifiers
        up?.post(tap: .cghidEventTap)
    }
}

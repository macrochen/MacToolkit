@preconcurrency import ApplicationServices
import Foundation

@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var isAccessibilityGranted = AXIsProcessTrusted()

    func refresh() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        // 使用 takeUnretainedValue 而不是 takeRetainedValue 避免内存问题
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }
}

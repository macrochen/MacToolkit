import AppKit
import Combine
@preconcurrency import ApplicationServices

/// 统一 Accessibility 权限管理
/// tap-enter 和 MouseKeyMapper 都需要此权限
@MainActor
class PermissionManager: ObservableObject {
    @Published var isAccessibilityGranted = false

    init() {
        refresh()
    }

    func refresh() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    /// 请求 Accessibility 权限（会弹出系统对话框）
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // 延迟刷新状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refresh()
        }
    }

    /// 打开系统偏好设置的辅助功能页面
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

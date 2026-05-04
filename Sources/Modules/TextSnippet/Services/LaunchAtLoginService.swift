import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var statusMessage = "登录时启动未启用。"

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
        statusMessage = isEnabled ? "已启用登录时启动。" : "登录时启动未启用。"
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            statusMessage = enabled ? "启用登录时启动失败。" : "关闭登录时启动失败。"
        }
    }
}

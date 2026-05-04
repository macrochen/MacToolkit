import SwiftUI
import AppKit
import Combine

/// MouseKeyMapper 模块 — 实现 ToolkitModule 协议
/// 原 MouseKeyMapper 的功能：鼠标手势映射键盘快捷键
class MouseKeyMapperModule: ToolkitModule {
    let id = "mouse-key-mapper"
    let name = "鼠标映射"
    let icon = "computermouse"

    let configManager = ConfigManager()
    let appMonitor = AppMonitor()
    private let eventEngine = EventEngine()
    private var cancellables = Set<AnyCancellable>()

    var tabView: AnyView {
        AnyView(
            MouseKeyMapperTabView(
                configManager: configManager,
                appMonitor: appMonitor
            )
        )
    }

    var settingsView: AnyView {
        AnyView(
            MouseKeyMapperSettingsSheet(configManager: configManager)
        )
    }

    func onAppLaunch() {
        eventEngine.start()
        updateEngine(for: appMonitor.currentAppBundleId)

        // 监听配置变化，自动更新引擎
        configManager.$appConfigs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateEngine(for: self.appMonitor.currentAppBundleId)
            }
            .store(in: &cancellables)

        // 监听当前应用变化，更新映射
        appMonitor.$currentAppBundleId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bundleId in
                guard let self = self else { return }
                self.updateEngine(for: bundleId)
            }
            .store(in: &cancellables)
    }

    func onAppTerminate() {
        eventEngine.stop()
    }

    func updateEngine(for bundleId: String?) {
        let mappings = configManager.getMappings(for: bundleId)
        eventEngine.updateMappings(mappings)
    }
}

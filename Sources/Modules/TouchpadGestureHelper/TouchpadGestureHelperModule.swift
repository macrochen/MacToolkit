import AppKit
import SwiftUI
import Combine

/// 触摸板手势助手模块
/// 可配置的触摸板手势映射
class TouchpadGestureHelperModule: ObservableObject, ToolkitModule {
    let id = "touchpad-gesture-helper"
    let name = "触摸板助手"
    let icon = "hand.tap"

    let configManager = GestureConfigManager()
    private let eventEngine = GestureEventEngine()
    private var cancellables = Set<AnyCancellable>()

    var tabView: AnyView {
        AnyView(TouchpadGestureTabView(module: self))
    }

    var settingsView: AnyView {
        AnyView(TouchpadGestureSettingsSheet(configManager: configManager))
    }

    func onAppLaunch() {
        print("[TouchpadGestureHelper] onAppLaunch called")
        // Register engine with the bridge so the C callback can find it
        GestureEventEngineBridge.shared.engine = eventEngine
        eventEngine.start()
        updateEngine(for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

        // 监听配置变化
        configManager.$appConfigs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateEngine(for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
            }
            .store(in: &cancellables)

        // 监听应用切换
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self.updateEngine(for: app.bundleIdentifier)
                }
            }
            .store(in: &cancellables)
    }

    func onAppTerminate() {
        eventEngine.stop()
    }

    private func updateEngine(for bundleId: String?) {
        let mappings = configManager.getMappings(for: bundleId)
        eventEngine.updateMappings(mappings)
    }
}

/// 触摸板手势 Tab 视图
struct TouchpadGestureTabView: View {
    @ObservedObject var module: TouchpadGestureHelperModule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 状态栏
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("已启用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let name = NSWorkspace.shared.frontmostApplication?.localizedName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            // 当前应用的手势规则
            if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                let mappings = module.configManager.getMappings(for: bundleId)
                if mappings.isEmpty {
                    Text("当前应用无手势映射")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mappings) { mapping in
                        HStack {
                            Image(systemName: mapping.gestureType.icon)
                                .font(.caption)
                                .frame(width: 20)
                            Text(mapping.gestureType.displayName)
                                .font(.caption)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(mapping.actionType.keyDescription)
                                .font(.caption.monospaced())
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                    }
                }
            }

            Divider()

            // 快捷操作
            HStack {
                Text("规则数: \(module.configManager.appConfigs.reduce(0) { $0 + $1.mappings.count })")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("详细设置") {
                    SettingsWindowController.shared.show(selectedModuleId: "touchpad-gesture-helper")
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(width: 340)
    }
}

/// 触摸板手势设置面板
struct TouchpadGestureSettingsSheet: View {
    @ObservedObject var configManager: GestureConfigManager
    @State private var selectedAppId: UUID?

    var body: some View {
        HSplitView {
            // 左侧：应用列表
            sidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 250)

            // 右侧：手势映射详情
            detail
                .frame(minWidth: 350)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            if selectedAppId == nil {
                selectedAppId = configManager.appConfigs.first?.id
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            Text("应用列表")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            List(selection: $selectedAppId) {
                if let global = configManager.appConfigs.first(where: { $0.bundleId == nil }) {
                    Label("全局默认", systemImage: "globe")
                        .tag(global.id)
                }

                let appConfigs = configManager.appConfigs.filter { $0.bundleId != nil }
                if !appConfigs.isEmpty {
                    Section("应用程序") {
                        ForEach(appConfigs) { appConfig in
                            Label(appConfig.appName, systemImage: "app")
                                .tag(appConfig.id)
                        }
                    }
                }
            }

            Divider()

            Button(action: addApp) {
                Label("添加应用", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let appId = selectedAppId,
           let configIndex = configManager.appConfigs.firstIndex(where: { $0.id == appId }) {
            GestureMappingDetailView(appConfig: $configManager.appConfigs[configIndex], configManager: configManager)
        } else {
            Text("请选择一个应用进行配置")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent

                let newConfig = GestureAppConfig(bundleId: bundleId, appName: name, mappings: [])
                configManager.appConfigs.append(newConfig)
                configManager.saveConfig()
                selectedAppId = newConfig.id
            }
        }
    }
}

/// 手势映射详情视图
struct GestureMappingDetailView: View {
    @Binding var appConfig: GestureAppConfig
    @ObservedObject var configManager: GestureConfigManager

    var body: some View {
        VStack {
            List {
                ForEach($appConfig.mappings) { $mapping in
                    HStack {
                        Picker("", selection: $mapping.gestureType) {
                            ForEach(TouchpadGestureType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                        .onChange(of: mapping.gestureType) { _, _ in configManager.saveConfig() }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        Picker("", selection: $mapping.actionType) {
                            ForEach(GestureActionType.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .onChange(of: mapping.actionType) { _, _ in configManager.saveConfig() }

                        Spacer()

                        Button(role: .destructive) {
                            if let idx = appConfig.mappings.firstIndex(where: { $0.id == mapping.id }) {
                                appConfig.mappings.remove(at: idx)
                                configManager.saveConfig()
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button("添加手势映射") {
                appConfig.mappings.append(GestureMapping(gestureType: .threeFingerTap, actionType: .cmdClick))
                configManager.saveConfig()
            }
            .padding()
        }
        .navigationTitle(appConfig.appName)
    }
}

import SwiftUI
import Carbon
import AppKit

/// MouseKeyMapper Tab 内容视图
/// 在 MacToolkit 的 popover Tab 中显示
struct MouseKeyMapperTabView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var appMonitor: AppMonitor

    @State private var selectedAppId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 状态栏
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("监听中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let name = appMonitor.currentAppName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // 当前应用的映射规则
            if let bundleId = appMonitor.currentAppBundleId {
                let mappings = configManager.getMappings(for: bundleId)
                if mappings.isEmpty {
                    Text("当前应用无专用映射，使用全局规则")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mappings) { mapping in
                        HStack {
                            Text(mapping.inputType.displayName)
                                .font(.caption)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(mapping.targetDescription ?? "未设置")
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
                Text("规则数: \(configManager.appConfigs.reduce(0) { $0 + $1.mappings.count })")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("详细设置") {
                    SettingsWindowController.shared.show(selectedModuleId: "mouse-key-mapper")
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(width: 340)
    }
}

/// MouseKeyMapper 详细设置面板
struct MouseKeyMapperSettingsSheet: View {
    @ObservedObject var configManager: ConfigManager
    @State private var selectedAppId: UUID?

    var body: some View {
        HSplitView {
            // 左侧：应用列表（固定显示）
            sidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 250)

            // 右侧：映射详情
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
            // 标题
            Text("应用列表")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // 应用列表
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

            // 添加按钮（底部）
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
            MappingDetailView(appConfig: $configManager.appConfigs[configIndex], configManager: configManager)
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

                let newConfig = AppConfig(bundleId: bundleId, appName: name, mappings: [])
                configManager.appConfigs.append(newConfig)
                configManager.saveConfig()
                selectedAppId = newConfig.id
            }
        }
    }
}

struct MappingDetailView: View {
    @Binding var appConfig: AppConfig
    @ObservedObject var configManager: ConfigManager

    var body: some View {
        VStack {
            List {
                ForEach($appConfig.mappings) { $mapping in
                    HStack {
                        Picker("", selection: $mapping.inputType) {
                            ForEach(MouseInputType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: mapping.inputType) { _, _ in configManager.saveConfig() }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        KeyRecorder(mapping: $mapping) {
                            configManager.saveConfig()
                        }

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

            Button("添加映射规则") {
                appConfig.mappings.append(KeyMapping(inputType: .scrollLeft, targetKeyCode: 0, targetModifiers: 0, targetDescription: "点击录制"))
                configManager.saveConfig()
            }
            .padding()
        }
        .navigationTitle(appConfig.appName)
    }
}

struct KeyRecorder: View {
    @Binding var mapping: KeyMapping
    var onFinish: () -> Void
    @State private var isRecording = false

    var body: some View {
        Button(action: { isRecording.toggle() }) {
            HStack {
                if isRecording {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                    Text("请按下快捷键...")
                } else {
                    Image(systemName: "keyboard")
                    Text(mapping.targetDescription ?? "点击设置")
                }
            }
            .padding(6)
            .background(isRecording ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .background(KeyEventHandlingView(isRecording: $isRecording) { event in
            if event.type == .flagsChanged { return }

            mapping.targetKeyCode = event.keyCode

            var cgFlags = CGEventFlags()
            if event.modifierFlags.contains(.command) { cgFlags.insert(.maskCommand) }
            if event.modifierFlags.contains(.control) { cgFlags.insert(.maskControl) }
            if event.modifierFlags.contains(.option) { cgFlags.insert(.maskAlternate) }
            if event.modifierFlags.contains(.shift) { cgFlags.insert(.maskShift) }

            mapping.targetModifiers = cgFlags.rawValue

            var desc = ""
            if event.modifierFlags.contains(.control) { desc += "⌃ " }
            if event.modifierFlags.contains(.option) { desc += "⌥ " }
            if event.modifierFlags.contains(.shift) { desc += "⇧ " }
            if event.modifierFlags.contains(.command) { desc += "⌘ " }
            if let chars = event.charactersIgnoringModifiers { desc += chars.uppercased() }

            mapping.targetDescription = desc
            isRecording = false
            onFinish()
        })
    }
}

struct KeyEventHandlingView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onKeyPress: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyCaptureNSView {
            view.isRecording = isRecording
            if isRecording {
                DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
            }
        }
    }
}

class KeyCaptureNSView: NSView {
    var isRecording = false
    var onKeyPress: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isRecording {
            onKeyPress?(event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if isRecording {
            onKeyPress?(event)
        } else {
            super.keyDown(with: event)
        }
    }
}

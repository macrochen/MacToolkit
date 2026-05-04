import SwiftUI

/// TextSnippet Tab 内容视图
/// 在 MacToolkit 的 popover Tab 中显示
struct TextSnippetTabView: View {
    @ObservedObject var snippetStore: SnippetStore
    @ObservedObject var permissionService: PermissionService
    @ObservedObject var typingService: TypingService
    @ObservedObject var shortcutManager: ShortcutManager
    @ObservedObject var launchAtLoginService: LaunchAtLoginService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 状态栏
            HStack {
                Circle()
                    .fill(permissionService.isAccessibilityGranted ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(permissionService.isAccessibilityGranted ? "权限已授权" : "需要辅助功能权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(typingService.lastTargetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider()

            // 快捷短语列表
            ForEach(snippetStore.snippets) { snippet in
                Button {
                    shortcutManager.triggerSnippet(id: snippet.id)
                } label: {
                    HStack {
                        Text(snippet.title)
                            .font(.system(size: 13))
                        Spacer()
                        Text(snippet.shortcut.displayText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .disabled(!snippet.isEnabled)
                .opacity(snippet.isEnabled ? 1.0 : 0.5)
            }

            Divider()

            // 底部操作
            HStack {
                Button("设置") {
                    SettingsWindowController.shared.show(selectedModuleId: "text-snippet")
                }
                .font(.caption)

                Spacer()

                if !permissionService.isAccessibilityGranted {
                    Button("授权") {
                        permissionService.requestAccessibilityPermission()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            // 状态信息
            Text(shortcutManager.statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            permissionService.refresh()
            launchAtLoginService.refresh()
            shortcutManager.configure(
                with: snippetStore.snippets,
                permissionService: permissionService,
                typingService: typingService
            )
        }
        .onChange(of: snippetStore.snippets) { _, snippets in
            shortcutManager.configure(
                with: snippets,
                permissionService: permissionService,
                typingService: typingService
            )
        }
    }
}

/// TextSnippet 设置面板（在统一设置窗口中展示）
struct TextSnippetSettingsSheet: View {
    @ObservedObject var snippetStore: SnippetStore
    @ObservedObject var permissionService: PermissionService
    @ObservedObject var typingService: TypingService
    @ObservedObject var shortcutManager: ShortcutManager
    @ObservedObject var launchAtLoginService: LaunchAtLoginService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(
                    permissionService.isAccessibilityGranted ? "辅助功能权限已授权" : "需要辅助功能权限",
                    systemImage: "figure.wave"
                )
                Spacer()
                Toggle(
                    "登录时启动",
                    isOn: Binding(
                        get: { launchAtLoginService.isEnabled },
                        set: { launchAtLoginService.setEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                Button("申请权限") {
                    permissionService.requestAccessibilityPermission()
                }
                Button("恢复默认") {
                    snippetStore.resetDefaults()
                }
            }
            .font(.subheadline)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach($snippetStore.snippets) { $snippet in
                        SnippetEditorCard(snippet: $snippet) { snippet in
                            typingService.send(snippet: snippet, permissionService: permissionService)
                        }
                    }
                }
            }

            // 状态栏
            VStack(alignment: .leading, spacing: 4) {
                Text(typingService.statusMessage)
                Text(shortcutManager.statusMessage)
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
        .padding(20)
    }
}

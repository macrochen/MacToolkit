import AppKit
import SwiftUI
import Combine

/// Finder Dock 助手模块
/// 点击 Dock 上的 Finder 图标时，如果有已打开的窗口就切换，否则新建窗口
@MainActor
class FinderDockHelperModule: ObservableObject, ToolkitModule {
    let id = "finder-dock-helper"
    let name = "Finder 助手"
    let icon = "finder"

    @Published var isEnabled = true
    private var observer: Any?

    var tabView: AnyView {
        AnyView(FinderDockHelperTabView(module: self))
    }

    var settingsView: AnyView {
        AnyView(FinderDockHelperSettingsView(module: self))
    }

    func onAppLaunch() {
        startMonitoring()
    }

    func onAppTerminate() {
        stopMonitoring()
    }

    private func startMonitoring() {
        // 监听 Finder 被激活的事件
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard self.isEnabled else { return }

            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.finder" else {
                return
            }

            // 延迟一小段时间，让系统处理完激活事件
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.handleFinderActivation()
            }
        }
    }

    private func stopMonitoring() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func handleFinderActivation() {
        // 使用 AppleScript 检查 Finder 是否有打开的窗口
        let script = """
        tell application "Finder"
            if (count of windows) is 0 then
                make new Finder window
            end if
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error = error {
                print("❌ [FinderDockHelper] AppleScript error: \(error)")
            }
        }
    }
}

/// Finder Dock 助手 Tab 视图
struct FinderDockHelperTabView: View {
    @ObservedObject var module: FinderDockHelperModule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(module.isEnabled ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(module.isEnabled ? "已启用" : "已禁用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("功能说明")
                    .font(.headline)

                Text("点击 Dock 上的 Finder 图标时：")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("如果有已打开的 Finder 窗口 → 切换到该窗口")
                    }
                    .font(.caption)

                    HStack(alignment: .top) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("如果没有打开的窗口 → 新建一个 Finder 窗口")
                    }
                    .font(.caption)
                }
                .padding(.leading, 8)
            }

            Spacer()

            HStack {
                Spacer()
                Toggle("启用此功能", isOn: $module.isEnabled)
                    .toggleStyle(.switch)
            }
        }
        .padding(12)
        .frame(width: 340)
    }
}

/// Finder Dock 助手设置视图
struct FinderDockHelperSettingsView: View {
    @ObservedObject var module: FinderDockHelperModule

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("启用 Finder Dock 助手", isOn: $module.isEnabled)
                .toggleStyle(.switch)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("功能说明")
                    .font(.headline)

                Text("macOS 默认行为：每次点击 Dock 上的 Finder 图标都会打开一个新窗口，导致屏幕上 Finder 窗口越来越多。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("启用此功能后：")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("监测到 Finder 被激活时，检查是否有已打开的窗口")
                    }

                    HStack(alignment: .top) {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("如果有窗口，不做任何操作（系统会自动切换到最近的窗口）")
                    }

                    HStack(alignment: .top) {
                        Image(systemName: "3.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("如果没有窗口，自动创建一个新 Finder 窗口")
                    }
                }
                .font(.subheadline)
                .padding(.leading, 8)
            }

            Spacer()
        }
        .padding(20)
    }
}

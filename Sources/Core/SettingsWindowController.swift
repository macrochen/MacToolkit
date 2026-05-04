import AppKit
import SwiftUI

/// 独立设置窗口管理器
/// 因为 MenuBarExtra popover 失焦会关闭 sheet，所以设置用独立窗口
@MainActor
class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    /// 可选：打开时跳转到指定模块
    func show(selectedModuleId: String? = nil) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let registry = ModuleRegistry.shared
        let settingsView = UnifiedSettingsView(registry: registry, initialModuleId: selectedModuleId)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "MacToolkit 设置"
        win.contentView = NSHostingView(rootView: settingsView)
        win.setContentSize(NSSize(width: 680, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 580, height: 420)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func close() {
        window?.close()
    }
}

/// 统一设置视图 — 使用 Tab 切换各模块
struct UnifiedSettingsView: View {
    @ObservedObject var registry: ModuleRegistry
    @State private var selectedTab: String

    init(registry: ModuleRegistry, initialModuleId: String? = nil) {
        self.registry = registry
        _selectedTab = State(initialValue: initialModuleId ?? registry.modules.first?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            if registry.modules.isEmpty {
                emptyState
            } else {
                tabBar
                Divider()
                moduleContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("暂无模块")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(registry.modules, id: \.id) { module in
                tabButton(module)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func tabButton(_ module: any ToolkitModule) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = module.id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: module.icon)
                    .font(.system(size: 13))
                Text(module.name)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == module.id
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear)
            )
            .foregroundStyle(selectedTab == module.id ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var moduleContent: some View {
        if let module = registry.modules.first(where: { $0.id == selectedTab }) {
            module.settingsView
                .id(module.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

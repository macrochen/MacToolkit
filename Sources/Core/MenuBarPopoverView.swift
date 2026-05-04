import SwiftUI

/// 统一 popover 视图 — 分段 Tab 切换各模块
struct MenuBarPopoverView: View {
    @ObservedObject var registry: ModuleRegistry

    var body: some View {
        VStack(spacing: 0) {
            if registry.modules.isEmpty {
                Text("暂无模块")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                // 分段选择器
                tabBar
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                Divider()

                // 当前模块内容
                moduleContent
            }
        }
        .frame(width: 360)
    }

    @ViewBuilder
    private var tabBar: some View {
        if registry.modules.count <= 4 {
            // 少量模块用 segmented picker
            Picker("", selection: $registry.selectedModuleId) {
                ForEach(registry.modules, id: \.id) { module in
                    Label(module.name, systemImage: module.icon)
                        .tag(module.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } else {
            // 模块多时用横向滚动图标栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(registry.modules, id: \.id) { module in
                        tabButton(module)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func tabButton(_ module: any ToolkitModule) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                registry.selectedModuleId = module.id
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: module.icon)
                    .font(.system(size: 16))
                Text(module.name)
                    .font(.caption2)
            }
            .foregroundStyle(registry.selectedModuleId == module.id ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var moduleContent: some View {
        if let module = registry.modules.first(where: { $0.id == registry.selectedModuleId }) {
            module.tabView
                .id(module.id)  // 确保切换时重建视图
        }
    }
}

import SwiftUI

/// 所有功能模块必须遵循的协议
/// 新增模块只需：1) 实现此协议  2) 在 ModuleRegistry 中注册
@MainActor
protocol ToolkitModule: Identifiable {
    /// 唯一标识，如 "text-snippet", "stand-up-timer"
    var id: String { get }

    /// Tab 显示名
    var name: String { get }

    /// SF Symbol 图标名
    var icon: String { get }

    /// Tab 内容视图（popover 中显示的简要视图）
    var tabView: AnyView { get }

    /// 设置视图（统一设置窗口中的详细设置）
    var settingsView: AnyView { get }

    /// App 启动时调用（注册热键、启动计时器等）
    func onAppLaunch()

    /// App 退出时调用（清理资源）
    func onAppTerminate()
}

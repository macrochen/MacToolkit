import SwiftUI

/// 模块注册表 — 持有所有功能模块实例
/// 新增模块只需在 init() 中加一行
@MainActor
class ModuleRegistry: ObservableObject {
    static let shared = ModuleRegistry()

    @Published var modules: [any ToolkitModule] = []
    @Published var selectedModuleId: String = ""

    private init() {
        // 在此注册所有模块
        modules = [
            TextSnippetModule(),
            StandUpTimerModule(),
            MouseKeyMapperModule(),
            FinderDockHelperModule(),
            TouchpadGestureHelperModule(),
        ]

        if let first = modules.first {
            selectedModuleId = first.id
        }
    }

    func launchAll() {
        modules.forEach { $0.onAppLaunch() }
    }

    func terminateAll() {
        modules.forEach { $0.onAppTerminate() }
    }
}

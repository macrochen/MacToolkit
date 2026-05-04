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
            ScreenshotModule(),
        ]

        if let first = modules.first {
            selectedModuleId = first.id
        }
    }

    func launchAll() {
        print("[ModuleRegistry] Launching \(modules.count) modules...")
        modules.forEach { module in
            print("[ModuleRegistry] Launching module: \(module.id) - \(module.name)")
            module.onAppLaunch()
        }
        print("[ModuleRegistry] All modules launched")
    }

    func terminateAll() {
        modules.forEach { $0.onAppTerminate() }
    }
}

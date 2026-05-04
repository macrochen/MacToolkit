import SwiftUI
import Combine

/// TextSnippet 模块 — 实现 ToolkitModule 协议
/// 原 tap-enter 的功能：全局快捷键发送文本片段
class TextSnippetModule: ToolkitModule {
    let id = "text-snippet"
    let name = "快捷短语"
    let icon = "keyboard.badge.ellipsis"

    // 模块持有的状态对象（生命周期跟随模块）
    let snippetStore = SnippetStore()
    let permissionService = PermissionService()
    let typingService = TypingService()
    let shortcutManager = ShortcutManager()
    let launchAtLoginService = LaunchAtLoginService()
    private var cancellables = Set<AnyCancellable>()

    var tabView: AnyView {
        AnyView(
            TextSnippetTabView(
                snippetStore: snippetStore,
                permissionService: permissionService,
                typingService: typingService,
                shortcutManager: shortcutManager,
                launchAtLoginService: launchAtLoginService
            )
        )
    }

    var settingsView: AnyView {
        AnyView(
            TextSnippetSettingsSheet(
                snippetStore: snippetStore,
                permissionService: permissionService,
                typingService: typingService,
                shortcutManager: shortcutManager,
                launchAtLoginService: launchAtLoginService
            )
        )
    }

    func onAppLaunch() {
        print("[TextSnippetModule] onAppLaunch called")
        print("[TextSnippetModule] Snippets count: \(snippetStore.snippets.count)")
        shortcutManager.configure(
            with: snippetStore.snippets,
            permissionService: permissionService,
            typingService: typingService
        )

        // 监听 snippet 变化，重新注册快捷键
        snippetStore.$snippets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snippets in
                guard let self = self else { return }
                print("[TextSnippetModule] Snippets changed: \(snippets.count)")
                self.shortcutManager.configure(
                    with: snippets,
                    permissionService: self.permissionService,
                    typingService: self.typingService
                )
            }
            .store(in: &cancellables)
    }

    func onAppTerminate() {
        // Carbon hotkey 在进程退出时自动清理
    }
}

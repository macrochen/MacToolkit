import Cocoa
import Combine

@MainActor
class AppMonitor: ObservableObject {
    @Published var currentAppBundleId: String?
    @Published var currentAppName: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 初始状态
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            updateActiveApp(activeApp)
        }

        // 监听应用切换
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                self?.updateActiveApp(app)
            }
            .store(in: &cancellables)
    }

    private func updateActiveApp(_ app: NSRunningApplication) {
        // 忽略自己
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        currentAppBundleId = app.bundleIdentifier
        currentAppName = app.localizedName
    }
}

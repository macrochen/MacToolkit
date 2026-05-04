import AppKit
import SwiftUI

@main
struct MacToolkitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("设置") {
                SettingsWindowController.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "square.grid.2x2")
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ModuleRegistry.shared.launchAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ModuleRegistry.shared.terminateAll()
    }

    // 当用户通过 Spotlight 再次打开时
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }
}

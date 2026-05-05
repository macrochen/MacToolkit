import SwiftUI
import AppKit
import Combine

/// StandUpTimer 模块 — 实现 ToolkitModule 协议
/// 原 StandUpTimer 的功能：三阶段久坐提醒 + 猫咪动画
class StandUpTimerModule: ToolkitModule {
    let id = "stand-up-timer"
    let name = "久坐提醒"
    let icon = "figure.stand"

    let settings = SettingsStore()
    let timerManager: TimerManager
    private let alertController = FloatingAlertWindowController()
    private var observer: AlertObserver?

    init() {
        let timer = TimerManager(settings: settings)
        self.timerManager = timer
    }

    var tabView: AnyView {
        AnyView(StandUpTimerTabView(timer: timerManager, settings: settings))
    }

    var settingsView: AnyView {
        AnyView(StandUpTimerSettingsSheet(timer: timerManager, settings: settings))
    }

    func onAppLaunch() {
        observer = AlertObserver(timer: timerManager, settings: settings, alertController: alertController)
        timerManager.start()
    }

    func onAppTerminate() {
        timerManager.pause()
        alertController.close()
    }
}

// MARK: - AppKit 级别监听器（不依赖 SwiftUI 视图渲染）

/// 透明浮动窗口管理器 — 猫咪提醒用
@MainActor
class FloatingAlertWindowController {
    private var window: NSWindow?
    private var isShowing = false

    func show(phase: TimerPhase, displaySeconds: Int, onDismiss: @escaping @MainActor () -> Void) {
        guard !isShowing else { return }
        isShowing = true

        if let existing = window {
            existing.orderOut(nil)
            existing.close()
            window = nil
        }

        guard let screen = NSScreen.main else {
            isShowing = false
            return
        }

        let catView = CatOverlayView(phase: phase, displaySeconds: displaySeconds) { [weak self] in
            guard let self = self, self.isShowing else { return }
            self.isShowing = false
            self.closeWindow()
            onDismiss()
        }

        let hostingView = NSHostingView(rootView: catView)

        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        win.setFrame(screen.frame, display: true)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    private func closeWindow() {
        window?.orderOut(nil)
        window?.close()
        window = nil
    }

    func close() {
        isShowing = false
        closeWindow()
    }
}

/// AppKit 级别监听器 — 不依赖 SwiftUI 视图渲染
@MainActor
class AlertObserver {
    private let timer: TimerManager
    private let settings: SettingsStore
    private let alertController: FloatingAlertWindowController
    private var cancellables = Set<AnyCancellable>()

    init(timer: TimerManager, settings: SettingsStore, alertController: FloatingAlertWindowController) {
        self.timer = timer
        self.settings = settings
        self.alertController = alertController

        timer.$showAlert
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard !self.timer.isResetting else { return }
                let phase = self.timer.currentPhase
                let seconds = self.settings.catDisplaySeconds
                self.alertController.show(phase: phase, displaySeconds: seconds) {
                    self.timer.nextPhase()
                }
            }
            .store(in: &cancellables)
    }
}

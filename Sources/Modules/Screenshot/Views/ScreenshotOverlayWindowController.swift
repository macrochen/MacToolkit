import AppKit
import SwiftUI

/// 截图全屏覆盖层窗口控制器
@MainActor
class ScreenshotOverlayWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: ScreenshotViewModel
    private var currentScreen: NSScreen?
    
    init(viewModel: ScreenshotViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func show() {
        print("[ScreenshotOverlayWindowController] show() called")
        
        if let existing = window, existing.isVisible {
            print("[ScreenshotOverlayWindowController] Window already visible, bringing to front")
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        // 获取主屏幕尺寸
        guard let screen = NSScreen.main else {
            print("[ScreenshotOverlayWindowController] ❌ No main screen")
            return
        }
        let screenFrame = screen.frame
        self.currentScreen = screen
        print("[ScreenshotOverlayWindowController] Screen frame: \(screenFrame)")
        
        // 创建全屏透明窗口
        let win = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // 窗口配置
        win.level = .screenSaver  // 最高层级，覆盖所有窗口
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.delegate = self
        win.isReleasedWhenClosed = false  // 关闭时不释放窗口
        win.isExcludedFromWindowsMenu = true  // 不出现在 Windows 菜单中
        
        // 设置内容视图
        let overlayView = ScreenshotOverlay(viewModel: viewModel, screen: screen)
            .ignoresSafeArea()
        win.contentView = NSHostingView(rootView: overlayView)
        
        // 显示窗口
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.window = win
        print("[ScreenshotOverlayWindowController] ✅ Window shown")
    }
    
    func close() {
        print("[ScreenshotOverlayWindowController] close() called")
        // 使用 orderOut 而不是 close，避免触发窗口关闭事件
        window?.orderOut(nil)
        window?.delegate = nil
        window = nil
    }
    
    /// 临时隐藏窗口（不销毁，用于弹出保存对话框等场景）
    func hide() {
        print("[ScreenshotOverlayWindowController] hide() called")
        window?.orderOut(nil)
    }
    
    /// 重新显示之前隐藏的窗口
    func showAgain() {
        print("[ScreenshotOverlayWindowController] showAgain() called")
        guard let win = window else { return }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidBecomeKey(_ notification: Notification) {
        // 窗口成为 key window 时，确保可以接收键盘事件
        print("[ScreenshotOverlayWindowController] Window became key")
    }
    
    // 防止窗口关闭时退出应用
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("[ScreenshotOverlayWindowController] windowShouldClose called")
        // 返回 true 允许关闭，但我们会使用 orderOut 来避免这个问题
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        print("[ScreenshotOverlayWindowController] windowWillClose called")
    }
    
    // MARK: - 键盘事件处理（备用机制）
    
    /// 处理键盘事件 - 作为 SwiftUI onKeyPress 的备用
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Escape 键退出
        if event.keyCode == 53 {
            print("[ScreenshotOverlayWindowController] Escape key pressed via window handler")
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.cancel()
            }
            return true
        }
        return false
    }
}

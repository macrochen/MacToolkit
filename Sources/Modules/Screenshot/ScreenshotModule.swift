import SwiftUI
import Combine

/// 截图模块
@MainActor
class ScreenshotModule: ToolkitModule {
    let id = "screenshot"
    let name = "截图"
    let icon = "camera.viewfinder"
    
    let viewModel = ScreenshotViewModel()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var overlayWindowController: ScreenshotOverlayWindowController?
    private var cancellables = Set<AnyCancellable>()
    
    var tabView: AnyView {
        AnyView(ScreenshotTabView(viewModel: viewModel, module: self))
    }
    
    var settingsView: AnyView {
        AnyView(ScreenshotTabView(viewModel: viewModel, module: self))
    }
    
    func onAppLaunch() {
        // 初始化覆盖层窗口控制器
        overlayWindowController = ScreenshotOverlayWindowController(viewModel: viewModel)
        
        // 设置覆盖层控制回调
        viewModel.onHideOverlay = { [weak self] in
            self?.overlayWindowController?.hide()
        }
        viewModel.onShowOverlay = { [weak self] in
            self?.overlayWindowController?.showAgain()
        }
        
        // 观察 isShowingOverlay 状态变化
        viewModel.$isShowingOverlay
            .sink { [weak self] isShowing in
                guard let self = self else { return }
                if isShowing {
                    self.overlayWindowController?.show()
                } else {
                    self.overlayWindowController?.close()
                }
            }
            .store(in: &cancellables)
        
        // 根据启用状态决定是否注册热键
        if viewModel.config.isEnabled {
            registerHotKey()
        }
    }
    
    func onAppTerminate() {
        overlayWindowController?.close()
        unregisterHotKey()
    }
    
    // MARK: - 启用/禁用截图功能
    
    func setEnabled(_ enabled: Bool) {
        viewModel.config.isEnabled = enabled
        viewModel.config.save()
        
        if enabled {
            registerHotKey()
        } else {
            unregisterHotKey()
        }
    }
    
    // MARK: - 快捷键注册
    
    func registerHotKey() {
        // 先注销旧的
        unregisterHotKey()
        
        let hotkey = viewModel.config.hotkey
        print("[ScreenshotModule] Registering hotkey: \(hotkey.displayString)")
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,  // 使用 session 级别，不干扰 HID
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                // 处理 tap 被禁用的情况
                if type == .tapDisabledByTimeout {
                    if let refcon = refcon {
                        let module = Unmanaged<ScreenshotModule>.fromOpaque(refcon).takeUnretainedValue()
                        if let tap = module.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }
                
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                
                let module = Unmanaged<ScreenshotModule>.fromOpaque(refcon).takeUnretainedValue()
                
                if type == .keyDown {
                    let flags = event.flags
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    
                    if module.handleKeyEvent(keyCode: keyCode, flags: flags) {
                        return nil
                    }
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            print("[ScreenshotModule] ❌ Failed to create event tap")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("[ScreenshotModule] Hotkey registered")
    }
    
    func unregisterHotKey() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }
    
    private func handleKeyEvent(keyCode: Int64, flags: CGEventFlags) -> Bool {
        let hotkey = viewModel.config.hotkey
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))
        
        if viewModel.handleShortcut(keyCode: keyCode, flags: flags) {
            return true
        }
        
        if Int64(hotkey.keyCode) == keyCode {
            let relevantFlags = nsFlags.intersection([.command, .option, .control, .shift])
            if relevantFlags == hotkey.modifiers {
                print("[ScreenshotModule] Hotkey triggered!")
                DispatchQueue.main.async { [weak self] in
                    self?.startScreenshot()
                }
                return true
            }
        }
        return false
    }
    
    // MARK: - 开始截图
    
    func startScreenshot() {
        viewModel.startCapture()
    }
    
    nonisolated deinit {
        // Cleanup is done in unregisterHotKey() and onAppTerminate()
    }
}

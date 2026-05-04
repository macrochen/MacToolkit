import SwiftUI

/// 截图模块
@MainActor
class ScreenshotModule: ToolkitModule {
    let id = "screenshot"
    let name = "截图"
    let icon = "camera.viewfinder"
    
    let viewModel = ScreenshotViewModel()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    var tabView: AnyView {
        AnyView(ScreenshotTabView(viewModel: viewModel, module: self))
    }
    
    var settingsView: AnyView {
        AnyView(ScreenshotTabView(viewModel: viewModel, module: self))
    }
    
    func onAppLaunch() {
        registerHotKey()
    }
    
    func onAppTerminate() {
        unregisterHotKey()
    }
    
    // MARK: - 快捷键注册
    
    func registerHotKey() {
        // 先注销旧的
        unregisterHotKey()
        
        let hotkey = viewModel.config.hotkey
        print("[ScreenshotModule] Registering hotkey: \(hotkey.displayString)")
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let module = Unmanaged<ScreenshotModule>.fromOpaque(refcon).takeUnretainedValue()
                
                if type == .keyDown {
                    let flags = event.flags
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    
                    if module.handleKeyEvent(keyCode: keyCode, flags: flags) {
                        return nil
                    }
                }
                
                return Unmanaged.passRetained(event)
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

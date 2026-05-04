import SwiftUI
import Carbon.HIToolbox

/// 截图模块
@MainActor
class ScreenshotModule: ToolkitModule {
    let id = "screenshot"
    let name = "截图"
    let icon = "camera.viewfinder"
    
    private let viewModel = ScreenshotViewModel()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    var tabView: AnyView {
        AnyView(ScreenshotTabView(viewModel: viewModel))
    }
    
    var settingsView: AnyView {
        AnyView(ScreenshotTabView(viewModel: viewModel))
    }
    
    func onAppLaunch() {
        registerHotKey()
    }
    
    func onAppTerminate() {
        unregisterHotKey()
    }
    
    // MARK: - 快捷键注册
    
    private func registerHotKey() {
        // 注册全局快捷键 ⌘+Shift+A
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // 安装事件处理器
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            // 在主线程执行截图
            DispatchQueue.main.async {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.startScreenshot()
                }
            }
            return noErr
        }
        
        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)
        eventHandler = handlerRef
        
        // 注册热键
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5343524e) // "SCRN"
        hotKeyID.id = 1
        
        RegisterEventHotKey(UInt32(0x00), UInt32(cmdKey | shiftKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef) // 0x00 = A key
    }
    
    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
    
    // MARK: - 开始截图
    
    func startScreenshot() {
        viewModel.startCapture()
    }
}

// MARK: - App 扩展

extension AppDelegate {
    func startScreenshot() {
        if let module = ModuleRegistry.shared.modules.first(where: { $0.id == "screenshot" }) as? ScreenshotModule {
            module.startScreenshot()
        }
    }
}

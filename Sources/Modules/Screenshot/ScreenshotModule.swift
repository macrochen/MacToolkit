import SwiftUI
import Carbon.HIToolbox

/// 截图模块
@MainActor
class ScreenshotModule: ToolkitModule {
    let id = "screenshot"
    let name = "截图"
    let icon = "camera.viewfinder"
    
    let viewModel = ScreenshotViewModel()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
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
        
        // 确保有有效的快捷键配置
        guard hotkey.keyCode > 0 else { return }
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // 安装事件处理器
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            DispatchQueue.main.async {
                if let module = ModuleRegistry.shared.modules.first(where: { $0.id == "screenshot" }) as? ScreenshotModule {
                    module.startScreenshot()
                }
            }
            return noErr
        }
        
        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)
        eventHandler = handlerRef
        
        // 注册热键 - 从配置读取
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5343524e) // "SCRN"
        hotKeyID.id = 1
        
        let keyCode = hotkey.keyCode
        let modifiers = hotkey.carbonModifiers
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    // MARK: - 开始截图
    
    func startScreenshot() {
        viewModel.startCapture()
    }
}

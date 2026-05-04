import SwiftUI

/// 快捷键录制器 - 捕获用户按键组合
struct HotkeyRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: NSEvent.ModifierFlags
    
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        
        if keyCode > 0 {
            parts.append(HotkeyConfig.keyCodeToString(keyCode))
        } else if !parts.isEmpty {
            parts.append("?")
        }
        
        return parts.isEmpty ? "点击录制快捷键" : parts.joined()
    }
    
    var body: some View {
        HStack {
            Text(displayString)
                .frame(minWidth: 100)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            
            if isRecording {
                Button("取消") {
                    stopRecording()
                }
                .font(.caption)
            }
        }
        .onTapGesture {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // 监听键盘事件
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // 获取修饰键状态
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // 忽略单独的修饰键按下
            if event.type == .flagsChanged {
                return nil
            }
            
            // 必须有至少一个修饰键
            let hasModifier = flags.contains(.command) || flags.contains(.shift) || 
                             flags.contains(.option) || flags.contains(.control)
            
            if hasModifier && event.type == .keyDown {
                // 录制成功
                self.keyCode = UInt32(event.keyCode)
                self.modifiers = flags
                self.stopRecording()
                return nil
            }
            
            // ESC 取消
            if event.keyCode == 53 { // ESC
                self.stopRecording()
                return nil
            }
            
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

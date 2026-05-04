import SwiftUI

/// 截图模块设置页
struct ScreenshotTabView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    var module: ScreenshotModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 快捷键设置
            GroupBox(label: Text("快捷键").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("截图快捷键:")
                        Spacer()
                        HotkeyRecorderView(
                            keyCode: Binding(
                                get: { viewModel.config.hotkey.keyCode },
                                set: { newKeyCode in
                                    viewModel.config.hotkey.keyCode = newKeyCode
                                    saveAndReRegister()
                                }
                            ),
                            modifiers: Binding(
                                get: { viewModel.config.hotkey.modifiers },
                                set: { newModifiers in
                                    viewModel.config.hotkey.modifiers = newModifiers
                                    saveAndReRegister()
                                }
                            )
                        )
                    }
                    
                    Text("点击录制区域，然后按下新的快捷键组合")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // 保存设置
            GroupBox(label: Text("保存").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("默认保存目录:")
                        Spacer()
                        Text(viewModel.config.saveDirectory.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 200)
                        
                        Button("更改") {
                            selectDirectory()
                        }
                    }
                    
                    Text("格式: PNG")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // 权限提示
            GroupBox(label: Text("权限").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: ScreenCaptureService.checkPermission() ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(ScreenCaptureService.checkPermission() ? .green : .orange)
                        
                        Text(ScreenCaptureService.checkPermission() ? "已授权屏幕录制权限" : "需要屏幕录制权限")
                    }
                    
                    if !ScreenCaptureService.checkPermission() {
                        Button("打开系统偏好设置") {
                            print("[ScreenshotTabView] Button tapped - opening System Preferences")
                            ScreenCaptureService.requestPermission()
                        }
                        .onAppear {
                            print("[ScreenshotTabView] Button appeared - permission not granted")
                        }
                    } else {
                        Text("屏幕录制权限已授权，可以正常使用截图功能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .padding(16)
        .frame(width: 400)
    }
    
    private func saveAndReRegister() {
        viewModel.config.save()
        module.registerHotKey()
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择保存目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.config.saveDirectory = url
            viewModel.config.save()
        }
    }
}

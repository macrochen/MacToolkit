import SwiftUI

/// 截图模块设置页
struct ScreenshotTabView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 快捷键设置
            GroupBox(label: Text("快捷键").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("截图快捷键:")
                        Spacer()
                        Text(viewModel.config.hotkey.displayString)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("默认: ⌘+Shift+A")
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
                            ScreenCaptureService.requestPermission()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .padding(16)
        .frame(width: 400)
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择保存目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.config.saveDirectory = url
        }
    }
}

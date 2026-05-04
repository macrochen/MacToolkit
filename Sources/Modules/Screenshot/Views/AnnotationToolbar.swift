import SwiftUI

/// 标注工具栏
struct AnnotationToolbar: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    
    // 预设颜色
    private let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
    
    var body: some View {
        HStack(spacing: 12) {
            // 标注工具
            ForEach(AnnotationType.allCases) { tool in
                ToolButton(
                    icon: tool.icon,
                    label: tool.name,
                    shortcut: tool.shortcut,
                    isSelected: viewModel.currentTool == tool
                ) {
                    viewModel.setTool(tool)
                    viewModel.enterAnnotationMode()
                }
            }
            
            // 颜色选择
            ColorPickerButton(viewModel: viewModel, presetColors: presetColors)
            
            // 撤销
            ToolButton(icon: "arrow.uturn.backward", label: "撤销", shortcut: "⌘Z") {
                viewModel.undo()
            }
            
            // OCR
            ToolButton(icon: "text.viewfinder", label: "OCR", shortcut: "⌘O") {
                viewModel.performOCR()
            }
            
            Divider()
                .frame(height: 20)
            
            // 保存文件
            ToolButton(icon: "doc.badge.arrow.down", label: "保存文件", shortcut: "⌘S") {
                viewModel.saveToFile()
            }
            .foregroundColor(.blue)
            
            // 复制到剪贴板
            ToolButton(icon: "doc.on.doc", label: "复制", shortcut: "⌘C") {
                viewModel.saveToClipboard()
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 工具按钮

struct ToolButton: View {
    let icon: String
    let label: String
    var shortcut: String?
    var isSelected: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 24, height: 24)
                
                Text(label)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(shortcut.map { "\(label) (\($0))" } ?? label)
    }
}

// MARK: - 颜色选择器按钮

struct ColorPickerButton: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let presetColors: [Color]
    
    @State private var showColorPicker = false
    
    var body: some View {
        Button(action: { showColorPicker.toggle() }) {
            Circle()
                .fill(viewModel.annotationEngine.currentColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(radius: 1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showColorPicker) {
            HStack(spacing: 8) {
                ForEach(presetColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .onTapGesture {
                            viewModel.annotationEngine.currentColor = color
                            showColorPicker = false
                        }
                }
                
                // 自定义颜色
                ColorPicker("", selection: $viewModel.annotationEngine.currentColor)
                    .labelsHidden()
                    .frame(width: 24, height: 24)
            }
            .padding(12)
        }
    }
}

// MARK: - 快捷键处理扩展

extension ScreenshotOverlay {
    /// 处理键盘快捷键
    func handleKeyPress(_ key: String) -> Bool {
        switch key {
        case "z":
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                viewModel.undo()
                return true
            }
        case "s":
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                viewModel.saveToFile()
                return true
            }
        case "c":
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                viewModel.saveToClipboard()
                return true
            }
        case "o":
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                viewModel.performOCR()
                return true
            }
        default:
            // 工具快捷键
            if let tool = AnnotationType.allCases.first(where: { $0.shortcut.lowercased() == key.lowercased() }) {
                viewModel.setTool(tool)
                viewModel.enterAnnotationMode()
                return true
            }
        }
        return false
    }
}

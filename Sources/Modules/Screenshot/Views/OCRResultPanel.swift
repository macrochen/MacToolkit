import SwiftUI

/// OCR 结果面板
struct OCRResultPanel: View {
    let text: String
    @ObservedObject var viewModel: ScreenshotViewModel
    @State private var editedText: String
    
    init(text: String, viewModel: ScreenshotViewModel) {
        self.text = text
        self.viewModel = viewModel
        self._editedText = State(initialValue: text)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text("OCR 识别结果")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Button(action: { viewModel.closeOCRPanel() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 文字编辑区
            TextEditor(text: $editedText)
                .font(.system(size: 13))
                .frame(minHeight: 100, maxHeight: 300)
                .border(Color.gray.opacity(0.3))
            
            // 操作按钮
            HStack {
                Button(action: { viewModel.copyOCRText(editedText) }) {
                    Label("复制文字", systemImage: "doc.on.doc")
                }
                
                Spacer()
                
                Button(action: { viewModel.closeOCRPanel() }) {
                    Text("关闭")
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

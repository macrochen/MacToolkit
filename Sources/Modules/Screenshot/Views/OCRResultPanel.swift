import SwiftUI

/// OCR 结果面板
struct OCRResultPanel: View {
    let text: String
    @ObservedObject var viewModel: ScreenshotViewModel
    let initialPosition: CGPoint
    let screenSize: CGSize

    @State private var editedText: String
    @State private var position: CGPoint?
    @State private var dragStart: CGPoint?
    @FocusState private var isEditorFocused: Bool
    
    init(text: String, viewModel: ScreenshotViewModel, initialPosition: CGPoint, screenSize: CGSize) {
        self.text = text
        self.viewModel = viewModel
        self.initialPosition = initialPosition
        self.screenSize = screenSize
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
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let start = dragStart ?? currentPosition
                        dragStart = start
                        position = clamped(CGPoint(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        ))
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
            
            // 文字编辑区
            TextEditor(text: $editedText)
                .font(.system(size: 13))
                .frame(width: 380, height: 220)
                .focused($isEditorFocused)
                .border(Color.gray.opacity(0.3))
            
            // 操作按钮
            HStack {
                Button(action: { viewModel.copyOCRText(editedText) }) {
                    Label("复制文字", systemImage: "doc.on.doc")
                }
                
                Button(action: { viewModel.saveToFile() }) {
                    Label("保存文件", systemImage: "doc.badge.arrow.down")
                }
                
                Spacer()
                
                Button(action: { viewModel.closeOCRPanel() }) {
                    Text("关闭")
                }
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .position(currentPosition)
        .onAppear {
            position = clamped(initialPosition)
            DispatchQueue.main.async {
                isEditorFocused = true
            }
        }
    }

    private var currentPosition: CGPoint {
        clamped(position ?? initialPosition)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 220), max(220, screenSize.width - 220)),
            y: min(max(point.y, 170), max(170, screenSize.height - 170))
        )
    }
}

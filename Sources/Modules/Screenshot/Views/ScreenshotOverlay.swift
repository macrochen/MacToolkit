import SwiftUI

/// 全屏截图覆盖层
struct ScreenshotOverlay: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩
                BackgroundMask(selection: viewModel.selection)
                    .ignoresSafeArea()
                
                // 选区
                if viewModel.state != .idle {
                    SelectionView(viewModel: viewModel, screenSize: geometry.size)
                }
                
                // 标注工具栏
                if viewModel.state == .selected || viewModel.state == .annotating {
                    AnnotationToolbar(viewModel: viewModel)
                        .position(x: viewModel.selection.midX,
                                  y: viewModel.selection.maxY + 30)
                }
                
                // OCR 结果面板
                if case .ocrResult(let text) = viewModel.state {
                    OCRResultPanel(text: text, viewModel: viewModel)
                        .position(x: viewModel.selection.maxX + 150,
                                  y: viewModel.selection.midY)
                }
                
                // OCR Loading
                if viewModel.state == .ocrLoading {
                    OCRLoadingView()
                        .position(x: viewModel.selection.midX,
                                  y: viewModel.selection.midY)
                }
                
                // Toast
                if viewModel.isShowingToast, let message = viewModel.toastMessage {
                    ToastView(message: message)
                        .position(x: geometry.size.width / 2,
                                  y: geometry.size.height - 50)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onKeyPress(.escape) {
                viewModel.cancel()
                return .handled
            }
        }
    }
}

// MARK: - 背景遮罩

struct BackgroundMask: View {
    let selection: CGRect
    
    var body: some View {
        if selection.width > 0 && selection.height > 0 {
            // 选区外的遮罩
            GeometryReader { geometry in
                Path { path in
                    // 全屏矩形
                    let fullRect = CGRect(origin: .zero, size: geometry.size)
                    path.addRect(fullRect)
                    // 挖空选区
                    path.addRect(selection)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            }
        } else {
            // 没有选区时全屏遮罩
            Color.black.opacity(0.3)
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
    }
}

// MARK: - OCR Loading

struct OCRLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("识别中...")
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

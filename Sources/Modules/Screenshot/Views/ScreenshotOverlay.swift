import SwiftUI

/// 全屏截图覆盖层
struct ScreenshotOverlay: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let screen: NSScreen
    
    var body: some View {
        // 直接使用屏幕尺寸，不依赖 GeometryReader（可能受 safe area 影响导致尺寸偏小）
        let screenSize = screen.frame.size
        
        ZStack {
            // 背景遮罩 - 点击空白区域可退出
            BackgroundMask(selection: viewModel.selection)
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    // 双击空白区域退出
                    viewModel.cancel()
                }
            
            // 选区
            if viewModel.state != .idle {
                SelectionView(viewModel: viewModel, screenSize: screenSize, screen: screen)
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
                    .position(x: screenSize.width / 2,
                              y: screenSize.height - 50)
            }
            
            // 关闭按钮 - 始终显示在右上角
            VStack {
                HStack {
                    Spacer()
                    Button(action: { viewModel.cancel() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                    .help("按 Esc 或双击空白区域也可退出")
                }
                Spacer()
            }
            
            // 底部提示
            if viewModel.state == .selecting || viewModel.state == .idle {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("拖拽选区 | Esc 退出 | 双击空白退出")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 注意：不在这里处理 Escape 键，由 CGEvent tap 统一处理
        // 避免与 NSApp 的 Escape 键处理冲突
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

import SwiftUI

/// 全屏猫咪动画提醒浮层 — 纯猫咪，铺满窗口，自动关闭
struct CatOverlayView: View {
    let displaySeconds: Int
    let onDismiss: @MainActor () -> Void

    @State private var showCat = false

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            CatVideoPlayerView(
                imageName: ["neko1", "neko2"].randomElement() ?? "neko1",
                displaySeconds: displaySeconds
            )
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(showCat ? 1.0 : 0.7)
            .opacity(showCat ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showCat = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(displaySeconds)) {
                onDismiss()
            }
        }
    }
}

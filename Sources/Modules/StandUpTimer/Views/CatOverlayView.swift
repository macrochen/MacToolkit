import SwiftUI

/// 全屏猫咪动画提醒浮层 — 猫咪 + 温馨提示，铺满窗口，自动关闭
struct CatOverlayView: View {
    let phase: TimerPhase
    let displaySeconds: Int
    let onDismiss: @MainActor () -> Void

    @State private var showCat = false
    @State private var showText = false
    
    // 根据阶段生成提示文案
    private var tip: String {
        switch phase {
        case .sitting:
            // 坐着阶段结束，提示该站立
            let tips = [
                "站起来，让身体舒展一下",
                "该站起来了，给脊柱换个姿势",
                "离开座椅，让双腿支撑你一会儿",
                "站立片刻，感受身体的觉醒"
            ]
            return tips.randomElement() ?? tips[0]
        case .standing:
            // 站立阶段结束，提示该活动
            let tips = [
                "走动几步，让血液流通起来",
                "活动一下手腕和颈椎",
                "去倒杯水，顺便伸展一下",
                "让身体流动起来，动一动"
            ]
            return tips.randomElement() ?? tips[0]
        case .moving:
            // 活动阶段结束，提示可以坐下继续
            let tips = [
                "休息好了，可以坐下了",
                "带着舒展的身体，继续加油",
                "坐下来，带着清醒的头脑继续",
                "身体已放松，坐下来继续吧"
            ]
            return tips.randomElement() ?? tips[0]
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }

                // 猫咪动画 - 按比例适配屏幕
                CatVideoPlayerView(
                    imageName: ["neko1", "neko2"].randomElement() ?? "neko1",
                    displaySeconds: displaySeconds
                )
                .scaledToFit()
                .frame(maxWidth: geo.size.width * 0.8, maxHeight: geo.size.height * 0.7)
                .scaleEffect(showCat ? 1.0 : 0.7)
                .opacity(showCat ? 1 : 0)
                
                // 温馨提示文案 - 垂直居中偏上
                VStack {
                    Spacer()
                    Text(tip)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.45))
                        )
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : -10)
                    Spacer()
                    Spacer()
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showCat = true
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
                showText = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(displaySeconds)) {
                onDismiss()
            }
        }
    }
}

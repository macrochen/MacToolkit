import SwiftUI

/// 纯 SwiftUI 绘制的可爱橘猫，带走路/摇尾巴动画
struct CatView: View {
    @State private var walkCycle: Bool = false
    @State private var tailWag: Bool = false
    @State private var blink: Bool = false
    @State private var bounce: Bool = false

    var body: some View {
        ZStack {
            // 身体
            Ellipse()
                .fill(Color.orange)
                .frame(width: 100, height: 70)
                .offset(y: 20)

            // 肚子
            Ellipse()
                .fill(Color(red: 1.0, green: 0.92, blue: 0.8))
                .frame(width: 60, height: 45)
                .offset(y: 25)

            // 左耳
            Triangle()
                .fill(Color.orange)
                .frame(width: 24, height: 28)
                .offset(x: -30, y: -38)
                .rotationEffect(.degrees(-8))

            // 左耳内
            Triangle()
                .fill(Color(red: 1.0, green: 0.75, blue: 0.75))
                .frame(width: 14, height: 16)
                .offset(x: -30, y: -36)
                .rotationEffect(.degrees(-8))

            // 右耳
            Triangle()
                .fill(Color.orange)
                .frame(width: 24, height: 28)
                .offset(x: 30, y: -38)
                .rotationEffect(.degrees(8))

            // 右耳内
            Triangle()
                .fill(Color(red: 1.0, green: 0.75, blue: 0.75))
                .frame(width: 14, height: 16)
                .offset(x: 30, y: -36)
                .rotationEffect(.degrees(8))

            // 头
            Circle()
                .fill(Color.orange)
                .frame(width: 80, height: 75)
                .offset(y: -20)

            // 左眼
            EyeView(blink: blink)
                .offset(x: -15, y: -24)

            // 右眼
            EyeView(blink: blink)
                .offset(x: 15, y: -24)

            // 鼻子
            Ellipse()
                .fill(Color(red: 1.0, green: 0.6, blue: 0.65))
                .frame(width: 10, height: 7)
                .offset(y: -12)

            // 嘴巴
            Path { path in
                path.move(to: CGPoint(x: 0, y: -7))
                path.addQuadCurve(to: CGPoint(x: -8, y: -2), control: CGPoint(x: -4, y: -4))
                path.move(to: CGPoint(x: 0, y: -7))
                path.addQuadCurve(to: CGPoint(x: 8, y: -2), control: CGPoint(x: 4, y: -4))
            }
            .stroke(Color(red: 0.6, green: 0.4, blue: 0.3), lineWidth: 1.5)
            .offset(y: -8)

            // 左胡须
            WhiskersPath(side: -1)
                .stroke(Color(red: 0.5, green: 0.35, blue: 0.25), lineWidth: 1)

            // 右胡须
            WhiskersPath(side: 1)
                .stroke(Color(red: 0.5, green: 0.35, blue: 0.25), lineWidth: 1)

            // 左前腿
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange)
                .frame(width: 18, height: 30)
                .offset(x: -22, y: 60)
                .rotationEffect(.degrees(walkCycle ? 10 : -10), anchor: .top)

            // 右前腿
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange)
                .frame(width: 18, height: 30)
                .offset(x: 22, y: 60)
                .rotationEffect(.degrees(walkCycle ? -10 : 10), anchor: .top)

            // 左后腿
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.9, green: 0.6, blue: 0.2))
                .frame(width: 18, height: 26)
                .offset(x: -26, y: 50)
                .rotationEffect(.degrees(walkCycle ? -8 : 8), anchor: .top)

            // 右后腿
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.9, green: 0.6, blue: 0.2))
                .frame(width: 18, height: 26)
                .offset(x: 26, y: 50)
                .rotationEffect(.degrees(walkCycle ? 8 : -8), anchor: .top)

            // 尾巴
            CatTail()
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 50, height: 50)
                .offset(x: 50, y: 15)
                .rotationEffect(.degrees(tailWag ? 15 : -15), anchor: .bottomLeading)
        }
        .offset(y: bounce ? -12 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                walkCycle = true
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                tailWag = true
            }
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(2)) {
                bounce = true
            }
            // 眨眼
            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.15)) { blink = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.15)) { blink = false }
                }
            }
        }
    }
}

/// 猫眼
struct EyeView: View {
    let blink: Bool

    var body: some View {
        ZStack {
            // 眼白
            Ellipse()
                .fill(Color.white)
                .frame(width: 16, height: blink ? 3 : 16)

            // 瞳孔
            if !blink {
                Circle()
                    .fill(Color(red: 0.2, green: 0.5, blue: 0.2))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
                // 高光
                Circle()
                    .fill(Color.white)
                    .frame(width: 3, height: 3)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

/// 三角形（猫耳）
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 胡须
struct WhiskersPath: Shape {
    let side: Int // -1 = left, 1 = right

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = CGFloat(side)
        path.move(to: CGPoint(x: sx * 20, y: -16))
        path.addLine(to: CGPoint(x: sx * 42, y: -20))
        path.move(to: CGPoint(x: sx * 20, y: -13))
        path.addLine(to: CGPoint(x: sx * 42, y: -13))
        path.move(to: CGPoint(x: sx * 20, y: -10))
        path.addLine(to: CGPoint(x: sx * 42, y: -6))
        return path
    }
}

/// 尾巴曲线
struct CatTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX * 0.3, y: rect.minY + rect.height * 0.3)
        )
        return path
    }
}

#Preview {
    CatView()
        .frame(width: 200, height: 200)
        .padding(40)
}

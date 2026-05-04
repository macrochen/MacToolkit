import SwiftUI

/// StandUpTimer Tab 内容视图
/// 在 MacToolkit 的 popover Tab 中显示
struct StandUpTimerTabView: View {
    @ObservedObject var timer: TimerManager
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 当前状态
            HStack {
                Text(timer.currentPhase.icon)
                    .font(.title2)
                Text(timer.currentPhase.label)
                    .font(.headline)
                Spacer()
                Text(timer.timeDisplay)
                    .font(.system(size: 24, design: .monospaced))
                    .monospacedDigit()
            }

            // 进度条
            ProgressView(value: progress)
                .tint(timer.isRunning ? .green : .orange)

            Divider()

            // 控制按钮
            HStack {
                Button(timer.isRunning ? "⏸ 暂停" : "▶ 继续") {
                    if timer.isRunning {
                        timer.pause()
                    } else {
                        timer.resume()
                    }
                }
                .font(.caption)

                Spacer()

                Button("⏭ 跳过阶段") {
                    timer.skipToNext()
                }
                .font(.caption)

                Spacer()

                Button("⚙ 设置") {
                    SettingsWindowController.shared.show(selectedModuleId: "stand-up-timer")
                }
                .font(.caption)
            }

            // 状态信息
            Text(timer.isRunning ? "计时中..." : "已暂停")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 340)
    }

    private var progress: Double {
        let total = Double(settings.duration(for: timer.currentPhase))
        guard total > 0 else { return 0 }
        return 1.0 - Double(timer.timeRemaining) / total
    }
}

/// StandUpTimer 设置面板（在统一设置窗口中展示）
struct StandUpTimerSettingsSheet: View {
    @ObservedObject var timer: TimerManager
    let settings: SettingsStore

    @State private var sittingMinutes: String = ""
    @State private var standingMinutes: String = ""
    @State private var movingMinutes: String = ""
    @State private var catSeconds: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // 上方：猫咪 + 计时
            timerStatusSection

            Divider()

            // 下方：参数设置
            settingsSection
        }
        .padding(16)
        .onAppear { loadSettings() }
    }

    // MARK: - 计时状态区域

    @ViewBuilder
    private var timerStatusSection: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32 // padding
            let catWidth = totalWidth * 0.4
            let detailWidth = totalWidth * 0.6

            HStack(spacing: 16) {
                // 左边：猫咪动画（40%）
                CatVideoPlayerView(
                    imageName: "neko1",
                    displaySeconds: 9999
                )
                .scaledToFit()
                .frame(width: catWidth - 16, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 右边：进度 + 时间 + 控制（60%）
                VStack(alignment: .leading, spacing: 10) {
                    // 阶段标签
                    HStack(spacing: 6) {
                        Text(timer.currentPhase.icon)
                        Text(timer.currentPhase.label)
                            .font(.headline)
                    }

                    // 时间
                    Text(timer.timeDisplay)
                        .font(.system(size: 28, design: .monospaced).bold())
                        .monospacedDigit()
                        .foregroundStyle(timer.isRunning ? .primary : .secondary)

                    // 水平进度条（从满到空）
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(timer.isRunning ? Color.green : Color.orange)
                            .frame(width: (detailWidth - 16) * progress)
                            .animation(.linear(duration: 1), value: progress)
                    }
                    .frame(height: 6)

                    // 控制按钮
                    HStack(spacing: 8) {
                        Button {
                            timer.isRunning ? timer.pause() : timer.resume()
                        } label: {
                            Label(
                                timer.isRunning ? "暂停" : "继续",
                                systemImage: timer.isRunning ? "pause.fill" : "play.fill"
                            )
                            .frame(width: 60)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button {
                            timer.skipToNext()
                        } label: {
                            Label("跳过", systemImage: "forward.fill")
                                .frame(width: 60)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Text(timer.isRunning ? "计时中" : "已暂停")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: detailWidth - 16)
            }
            .padding(16)
        }
        .frame(height: 155)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var progress: Double {
        let total = Double(settings.duration(for: timer.currentPhase))
        guard total > 0 else { return 0 }
        return Double(timer.timeRemaining) / total
    }

    // MARK: - 设置区域

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("计时参数")
                .font(.headline)

            VStack(spacing: 8) {
                settingRow(icon: "🪑", label: "坐着办公时长", text: $sittingMinutes, unit: "分钟")
                settingRow(icon: "🧍", label: "站立时长", text: $standingMinutes, unit: "分钟")
                settingRow(icon: "🚶", label: "活动时长", text: $movingMinutes, unit: "分钟")

                Divider()
                    .padding(.vertical, 2)

                settingRow(icon: "🐱", label: "猫咪显示时长", text: $catSeconds, unit: "秒")
            }

            HStack {
                Button("重置默认") {
                    sittingMinutes = "20"
                    standingMinutes = "8"
                    movingMinutes = "2"
                    catSeconds = "10"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("保存并重启计时") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func settingRow(icon: String, label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(icon)
                .font(.title3)
            Text(label)
                .frame(width: 120, alignment: .leading)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .multilineTextAlignment(.center)
            Text(unit)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 数据操作

    private func loadSettings() {
        sittingMinutes = "\(settings.sittingDuration)"
        standingMinutes = "\(settings.standingDuration)"
        movingMinutes = "\(settings.movingDuration)"
        catSeconds = "\(settings.catDisplaySeconds)"
    }

    private func saveSettings() {
        if let val = Int(sittingMinutes), val > 0 { settings.sittingDuration = val }
        if let val = Int(standingMinutes), val > 0 { settings.standingDuration = val }
        if let val = Int(movingMinutes), val > 0 { settings.movingDuration = val }
        if let val = Int(catSeconds), val >= 3 { settings.catDisplaySeconds = val }
        timer.reset()
        timer.start()
    }
}

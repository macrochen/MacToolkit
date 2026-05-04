import Foundation
import Combine

@MainActor
class TimerManager: ObservableObject {
    @Published var currentPhase: TimerPhase = .sitting
    @Published var timeRemaining: Int = 0
    @Published var isRunning: Bool = false
    @Published var showAlert: Bool = false

    private var timer: Timer?
    let settings: SettingsStore

    /// 标记正在重置中，防止 AlertObserver 误触发
    private(set) var isResetting = false

    init(settings: SettingsStore) {
        self.settings = settings
        self.timeRemaining = settings.duration(for: .sitting)
    }

    var timeDisplay: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        timer?.invalidate()
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timer?.invalidate()
                self.isRunning = false
                self.showAlert = true
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
    }

    func resume() {
        start()
    }

    func nextPhase() {
        currentPhase = currentPhase.next
        timeRemaining = settings.duration(for: currentPhase)
        showAlert = false
        start()
    }

    func skipToNext() {
        timer?.invalidate()
        nextPhase()
    }

    /// 完全重置计时器（用于设置变更后）
    func reset() {
        isResetting = true
        timer?.invalidate()
        timer = nil
        isRunning = false
        currentPhase = .sitting
        timeRemaining = settings.duration(for: .sitting)
        showAlert = false
        // 延迟清除标记，确保 Combine 事件已经处理完毕
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isResetting = false
        }
    }
}

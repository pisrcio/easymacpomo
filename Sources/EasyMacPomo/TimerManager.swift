import Foundation
import Combine

enum TimerState {
    case idle
    case running
    case paused
    case completed
}

class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var remainingSeconds: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var todayMinutes: Int = 0

    private var timer: Timer?
    private var originalDuration: Int = 0

    var todayTotalMinutes: Int {
        switch state {
        case .running, .paused:
            return todayMinutes + (originalDuration - remainingSeconds) / 60
        default:
            return todayMinutes
        }
    }

    var todayDisplay: String {
        let total = todayTotalMinutes
        if total >= 60 {
            return "\(total / 60)h \(total % 60)m"
        }
        return "\(total)m"
    }

    var displayTime: String {
        switch state {
        case .idle:
            return ""
        case .running, .paused:
            return formatTime(remainingSeconds)
        case .completed:
            return formatTime(originalDuration + elapsedSeconds)
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    func start(seconds: Int) {
        originalDuration = seconds
        remainingSeconds = seconds
        elapsedSeconds = 0
        state = .running
        FocusManager.enableDoNotDisturb()
        startTimer()
    }

    func togglePause() {
        if state == .paused {
            state = .running
            startTimer()
        } else if state == .running {
            state = .paused
            timer?.invalidate()
            timer = nil
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
        remainingSeconds = 0
        elapsedSeconds = 0
        FocusManager.disableDoNotDisturb()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        remainingSeconds = 0
        elapsedSeconds = 0
        FocusManager.disableDoNotDisturb()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        switch state {
        case .running:
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                todayMinutes += originalDuration / 60
                state = .completed
                elapsedSeconds = 0
            }
        case .completed:
            elapsedSeconds += 1
        default:
            break
        }
    }
}

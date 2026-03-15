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

    private var timer: Timer?
    private var originalDuration: Int = 0

    var displayTime: String {
        switch state {
        case .idle:
            return ""
        case .running, .paused:
            let mins = remainingSeconds / 60
            let secs = remainingSeconds % 60
            return String(format: "%02d:%02d", mins, secs)
        case .completed:
            let total = originalDuration + elapsedSeconds
            let mins = total / 60
            let secs = total % 60
            return String(format: "%02d:%02d", mins, secs)
        }
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

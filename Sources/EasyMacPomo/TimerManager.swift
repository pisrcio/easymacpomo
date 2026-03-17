import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

enum TimerState {
    case idle
    case running
    case paused
    case completed
}

struct TodoItem: Identifiable {
    let id = UUID()
    var text: String
    var isDone: Bool = false
}

class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var remainingSeconds: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var restSeconds: Int = 0
    @Published var todayMinutes: Int = 0
    @Published var todos: [TodoItem] = []
    @Published var isAddingTodo: Bool = false

    private var timer: Timer?
    private var restTimer: Timer?
    private var hotkeyRef: EventHotKeyRef?
    private var todoInputPanel: TodoInputPanel?
    private(set) var originalDuration: Int = 0
    private var pausedFromCompleted: Bool = false

    private static weak var shared: TimerManager?

    init() {
        TimerManager.shared = self
        registerHotkey()
        todoInputPanel = TodoInputPanel(timerManager: self)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil)
    }

    deinit {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        if state == .running {
            pausedFromCompleted = false
            state = .paused
            timer?.invalidate()
            timer = nil
        } else if state == .completed {
            pausedFromCompleted = true
            state = .paused
            timer?.invalidate()
            timer = nil
        }
    }

    func showTodoInput() {
        todoInputPanel?.show()
    }

    private func registerHotkey() {
        // Carbon hotkey: works globally without Accessibility permissions
        let hotKeyID = EventHotKeyID(signature: OSType(0x504F4D4F), id: 1) // "POMO"
        // Modifiers: cmdKey=0x100, optionKey=0x800, controlKey=0x1000
        let modifiers: UInt32 = UInt32(cmdKey | optionKey | controlKey)
        let keyCode: UInt32 = 0x2A // kVK_ANSI_Backslash

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    TimerManager.shared?.showTodoInput()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        self.hotkeyRef = hotKeyRef
    }

    private var sessionElapsedMinutes: Int {
        switch state {
        case .running, .paused:
            return (originalDuration - remainingSeconds) / 60
        default:
            return 0
        }
    }

    var todayTotalMinutes: Int {
        return todayMinutes + sessionElapsedMinutes
    }

    func setTodayTotal(_ total: Int) {
        todayMinutes = total - sessionElapsedMinutes
    }

    func addTodo(_ text: String) {
        guard !text.isEmpty else { return }
        todos.append(TodoItem(text: text))
    }

    func toggleTodo(_ id: UUID) {
        if let index = todos.firstIndex(where: { $0.id == id }) {
            todos[index].isDone.toggle()
            if todos[index].isDone {
                let todoId = id
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.removeTodo(todoId)
                }
            }
        }
    }

    func removeTodo(_ id: UUID) {
        todos.removeAll { $0.id == id }
    }

    var todayDisplay: String {
        let total = todayTotalMinutes
        if total >= 60 {
            return "\(total / 60)h \(total % 60)m"
        }
        return "\(total)m"
    }

    var restDisplay: String {
        return formatTime(restSeconds)
    }

    var displayTime: String {
        switch state {
        case .idle:
            return ""
        case .running:
            return formatTime(remainingSeconds)
        case .paused:
            if pausedFromCompleted {
                return formatTime(originalDuration + elapsedSeconds)
            }
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
        restTimer?.invalidate()
        restTimer = nil
        restSeconds = 0
        originalDuration = seconds
        remainingSeconds = seconds
        elapsedSeconds = 0
        state = .running
        FocusManager.enableDoNotDisturb()
        startTimer()
    }

    func togglePause() {
        if state == .paused {
            if pausedFromCompleted {
                pausedFromCompleted = false
                state = .completed
            } else {
                state = .running
            }
            startTimer()
        } else if state == .running {
            pausedFromCompleted = false
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
        startRestTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        remainingSeconds = 0
        elapsedSeconds = 0
        FocusManager.disableDoNotDisturb()
        startRestTimer()
    }

    private func startRestTimer() {
        restSeconds = 0
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.restSeconds += 1
        }
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

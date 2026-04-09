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

struct TodoItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var isDone: Bool = false

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.isDone = false
    }
}

struct TodayData: Codable {
    var minutes: Int
    var date: String // "yyyy-MM-dd" using 2AM boundary
}

class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle {
        didSet {
            if state == .paused {
                startActivityMonitor()
                startPauseTimer()
            } else {
                stopActivityMonitor()
                stopPauseTimer()
            }
        }
    }
    @Published var remainingSeconds: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var restSeconds: Int = 0
    @Published var pauseSeconds: Int = 0
    @Published var sumMinutes: Int = 0
    @Published var todos: [TodoItem] = []
    @Published var isAddingTodo: Bool = false

    private var timer: Timer?
    private var restTimer: Timer?
    private var pauseTimer: Timer?
    private var activityMonitorTimer: Timer?
    private var pauseGraceEndTime: Date?
    private var recentActivityTimestamps: [Date] = []
    private var lastPolledEventTime: Date?
    private var pendingDeletions: [UUID: DispatchWorkItem] = [:]
    private var hotkeyRef: EventHotKeyRef?
    private var todoInputPanel: TodoInputPanel?
    private(set) var originalDuration: Int = 0
    private var pausedFromCompleted: Bool = false

    /// Grace period after pausing during which user activity is ignored.
    private static let pauseGracePeriod: TimeInterval = 30
    /// Rolling window used to count activity events toward auto-resume.
    private static let activityWindow: TimeInterval = 30
    /// Number of activity events required within the window to auto-resume.
    private static let requiredActivityEvents: Int = 5

    /// Event types that count as user activity for auto-resume.
    private static let monitoredEventTypes: [CGEventType] = [
        .keyDown,
        .flagsChanged,
        .mouseMoved,
        .leftMouseDown,
        .leftMouseUp,
        .leftMouseDragged,
        .rightMouseDown,
        .rightMouseUp,
        .rightMouseDragged,
        .otherMouseDown,
        .otherMouseUp,
        .otherMouseDragged,
        .scrollWheel
    ]

    private static weak var shared: TimerManager?
    private static let storageDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".easymacpomo")
    private static let todosFile = storageDir.appendingPathComponent("todos.json")
    private static let todayFile = storageDir.appendingPathComponent("today.json")

    init() {
        TimerManager.shared = self
        loadPersistedState()
        registerHotkey()
        todoInputPanel = TodoInputPanel(timerManager: self)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(pauseIfWorking),
            name: NSWorkspace.willSleepNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(pauseIfWorking),
            name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
    }

    deinit {
        activityMonitorTimer?.invalidate()
        pauseTimer?.invalidate()
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func pauseIfWorking(_ notification: Notification) {
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

    func setSumTotal(_ total: Int) {
        sumMinutes = total
        saveSumMinutes()
    }

    func resetSumMinutes() {
        sumMinutes = 0
        saveSumMinutes()
    }

    func addTodo(_ text: String) {
        guard !text.isEmpty else { return }
        todos.append(TodoItem(text: text))
        saveTodos()
    }

    func toggleTodo(_ id: UUID) {
        if let index = todos.firstIndex(where: { $0.id == id }) {
            todos[index].isDone.toggle()
            saveTodos()
            if todos[index].isDone {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.pendingDeletions.removeValue(forKey: id)
                    self?.removeTodo(id)
                }
                pendingDeletions[id] = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
            } else {
                pendingDeletions[id]?.cancel()
                pendingDeletions.removeValue(forKey: id)
            }
        }
    }

    func removeTodo(_ id: UUID) {
        todos.removeAll { $0.id == id }
        saveTodos()
    }

    var sumDisplay: String {
        if sumMinutes >= 60 {
            return "\(sumMinutes / 60)h \(sumMinutes % 60)m"
        }
        return "\(sumMinutes)m"
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
            return formatTime(pauseSeconds)
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

    private func startPauseTimer() {
        pauseSeconds = 0
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.pauseSeconds += 1
        }
    }

    private func stopPauseTimer() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        pauseSeconds = 0
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func startActivityMonitor() {
        activityMonitorTimer?.invalidate()
        pauseGraceEndTime = Date().addingTimeInterval(Self.pauseGracePeriod)
        recentActivityTimestamps.removeAll()
        lastPolledEventTime = nil
        activityMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForActivity()
        }
    }

    private func stopActivityMonitor() {
        activityMonitorTimer?.invalidate()
        activityMonitorTimer = nil
        pauseGraceEndTime = nil
        recentActivityTimestamps.removeAll()
        lastPolledEventTime = nil
    }

    private func checkForActivity() {
        guard state == .paused, let graceEnd = pauseGraceEndTime else {
            stopActivityMonitor()
            return
        }

        let now = Date()

        // Ignore all activity during the grace period right after pausing.
        if now < graceEnd {
            return
        }

        // Timestamp of the most recent event across all monitored types.
        let minIdle = Self.monitoredEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .infinity
        let currentEventTime = now.addingTimeInterval(-minIdle)

        // Count it as a new event if it happened after the grace period and
        // after anything we've already recorded.
        let threshold = lastPolledEventTime ?? graceEnd
        if currentEventTime > threshold {
            recentActivityTimestamps.append(currentEventTime)
            lastPolledEventTime = currentEventTime
        }

        // Drop events that have fallen out of the rolling window.
        let windowStart = now.addingTimeInterval(-Self.activityWindow)
        recentActivityTimestamps.removeAll { $0 < windowStart }

        if recentActivityTimestamps.count >= Self.requiredActivityEvents {
            togglePause()
        }
    }

    private func tick() {
        switch state {
        case .running:
            if remainingSeconds > 0 {
                remainingSeconds -= 1
                if remainingSeconds % 60 == 0 {
                    sumMinutes += 1
                    saveSumMinutes()
                }
            } else {
                state = .completed
                elapsedSeconds = 0
            }
        case .completed:
            elapsedSeconds += 1
            if elapsedSeconds % 60 == 0 {
                sumMinutes += 1
                saveSumMinutes()
            }
        default:
            break
        }
    }

    // MARK: - Persistence

    /// Returns today's date string using a 2AM boundary (before 2AM counts as previous day).
    private static func effectiveDateString() -> String {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let effectiveDate = hour < 2
            ? calendar.date(byAdding: .day, value: -1, to: now)!
            : now
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: effectiveDate)
    }

    private func ensureStorageDir() {
        try? FileManager.default.createDirectory(at: Self.storageDir, withIntermediateDirectories: true)
    }

    private func loadPersistedState() {
        ensureStorageDir()

        // Load todos
        if let data = try? Data(contentsOf: Self.todosFile),
           let loaded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = loaded
        }

        // Load sum minutes, resetting if the effective date has changed
        if let data = try? Data(contentsOf: Self.todayFile),
           let loaded = try? JSONDecoder().decode(TodayData.self, from: data) {
            if loaded.date == Self.effectiveDateString() {
                sumMinutes = loaded.minutes
            } else {
                sumMinutes = 0
                saveSumMinutes()
            }
        }
    }

    private func saveTodos() {
        ensureStorageDir()
        if let data = try? JSONEncoder().encode(todos) {
            try? data.write(to: Self.todosFile, options: .atomic)
        }
    }

    private func saveSumMinutes() {
        ensureStorageDir()
        let todayData = TodayData(minutes: sumMinutes, date: Self.effectiveDateString())
        if let data = try? JSONEncoder().encode(todayData) {
            try? data.write(to: Self.todayFile, options: .atomic)
        }
    }
}

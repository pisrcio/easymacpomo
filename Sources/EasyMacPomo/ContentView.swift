import SwiftUI

struct ContentView: View {
    private static let todoSpace = "todoList"

    @ObservedObject var timerManager: TimerManager
    @State private var todayEditText: String = ""
    @FocusState private var isTodayFocused: Bool
    @State private var newTodoText: String = ""
    @State private var showResetTodayAlert: Bool = false
    @State private var draggingTodoID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dropSlot: DropSlot?
    @State private var todoFrames: [TodoFrame] = []

    var body: some View {
        VStack(spacing: 16) {
            switch timerManager.state {
            case .idle:
                idleView
            case .running, .paused:
                activeView
            case .completed:
                completedView
            }

            todayField

            if showResetTodayAlert {
                VStack(spacing: 8) {
                    Text("Reset Total")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Are you sure?")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showResetTodayAlert = false
                        }
                        .controlSize(.small)
                        Button("Reset") {
                            timerManager.resetSumMinutes()
                            todayEditText = timerManager.sumDisplay
                            showResetTodayAlert = false
                        }
                        .controlSize(.small)
                        .tint(.red)
                    }
                }
                .padding(12)
                .background(.background)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }

            todoList
        }
        .padding(20)
        .frame(width: 220)
        // The menu bar window proposes its minimum height, which squeezes the
        // todo bands into each other once the list grows. Reporting the ideal
        // height instead makes the window size to the content.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func commitSumEdit() {
        if let mins = Int(todayEditText) {
            timerManager.setSumTotal(mins)
        }
        isTodayFocused = false
        todayEditText = timerManager.sumDisplay
    }

    private var todayField: some View {
        HStack(spacing: 4) {
            Text("Σ")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("0", text: $todayEditText)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 50)
                .focused($isTodayFocused)
                .onAppear {
                    todayEditText = timerManager.sumDisplay
                    DispatchQueue.main.async {
                        isTodayFocused = false
                    }
                }
                .onChange(of: isTodayFocused) { focused in
                    if focused {
                        todayEditText = "\(timerManager.sumMinutes)"
                    } else {
                        commitSumEdit()
                    }
                }
                .onChange(of: timerManager.sumMinutes) { _ in
                    if !isTodayFocused {
                        todayEditText = timerManager.sumDisplay
                    }
                }
                .onSubmit {
                    commitSumEdit()
                }
                .onExitCommand {
                    commitSumEdit()
                }
            Button {
                showResetTodayAlert = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reset today's total")
        }
    }

    private var todoList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(TodoSection.allCases, id: \.self) { section in
                todoSection(section)
            }

            if timerManager.isAddingTodo {
                TextField("New todo...", text: $newTodoText)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        timerManager.addTodo(newTodoText)
                        newTodoText = ""
                        timerManager.isAddingTodo = false
                    }
                    .onExitCommand {
                        newTodoText = ""
                        timerManager.isAddingTodo = false
                    }
            }
        }
        .coordinateSpace(name: Self.todoSpace)
        .onPreferenceChange(TodoFrameKey.self) { todoFrames = $0 }
        .overlay(alignment: .top) {
            if let y = dropIndicatorY() {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .padding(.horizontal, 7)
                    .offset(y: y - 1)
            }
        }
    }

    /// Publishes a row's (or a band's) live frame so the drag gesture can hit
    /// test against it — AppKit drag sessions do not survive the menu bar
    /// window, so reordering is driven by plain gestures instead.
    private func frameReporter(id: UUID?, section: TodoSection) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: TodoFrameKey.self,
                value: [TodoFrame(id: id, section: section, rect: geo.frame(in: .named(Self.todoSpace)))])
        }
    }

    /// The list is left untouched while a drag is in flight: moving a row
    /// between bands would rebuild it in another container and cancel the
    /// gesture mid-drag. The row rides along on an offset, an insertion line
    /// shows where it will land, and the move is applied on release.
    private func dragGesture(for todo: TodoItem) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.todoSpace))
            .onChanged { value in
                if draggingTodoID != todo.id { draggingTodoID = todo.id }
                dragOffset = value.translation.height
                dropSlot = slot(for: todo.id, at: value.location)
            }
            .onEnded { _ in
                if let slot = dropSlot {
                    timerManager.moveTodo(todo.id, before: slot.beforeID, section: slot.section)
                }
                draggingTodoID = nil
                dragOffset = 0
                dropSlot = nil
            }
    }

    /// Maps the pointer to a slot: the band it is vertically inside (clamped to
    /// the first and last band so a drag past the ends still lands), then the
    /// first row in that band whose midpoint is below the pointer.
    private func slot(for dragged: UUID, at point: CGPoint) -> DropSlot? {
        let bands = todoFrames.filter { $0.id == nil }.sorted { $0.rect.minY < $1.rect.minY }
        guard let band = bands.first(where: { point.y < $0.rect.maxY }) ?? bands.last else { return nil }

        let beforeID = todoFrames
            .filter { $0.id != nil && $0.id != dragged && $0.section == band.section }
            .sorted { $0.rect.midY < $1.rect.midY }
            .first { point.y < $0.rect.midY }?
            .id
        return DropSlot(section: band.section, beforeID: beforeID)
    }

    /// Where to draw the insertion line, in the list's coordinate space.
    private func dropIndicatorY() -> CGFloat? {
        guard let slot = dropSlot else { return nil }
        if let beforeID = slot.beforeID {
            return todoFrames.first { $0.id == beforeID }.map { $0.rect.minY - 2 }
        }
        let rows = todoFrames.filter { $0.id != nil && $0.id != draggingTodoID && $0.section == slot.section }
        if let bottom = rows.map({ $0.rect.maxY }).max() {
            return bottom + 2
        }
        return todoFrames.first { $0.id == nil && $0.section == slot.section }?.rect.midY
    }

    /// One tinted band of the list. The band reports its own frame too, so a
    /// drag can land in it even when the section is empty.
    private func todoSection(_ section: TodoSection) -> some View {
        let items = timerManager.todos(in: section)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { todo in
                todoRow(todo)
                    .background(frameReporter(id: todo.id, section: section))
                    .offset(y: draggingTodoID == todo.id ? dragOffset : 0)
                    .zIndex(draggingTodoID == todo.id ? 1 : 0)
                    .gesture(dragGesture(for: todo))
            }

            if items.isEmpty {
                Text(section.emptyLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .background(section.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
        .background(frameReporter(id: nil, section: section))
        .contentShape(Rectangle())
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 6) {
            Text("- \(todo.text)")
                .font(.system(size: 11))
                .foregroundStyle(todo.isDone ? .secondary : .primary)
                .strikethrough(todo.isDone)
                .lineLimit(2)
                .help(todo.text)
            Spacer()
            Button {
                timerManager.toggleTodo(todo.id)
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(todo.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .opacity(draggingTodoID == todo.id ? 0.4 : 1)
        .contentShape(Rectangle())
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            if timerManager.restSeconds > 0 {
                Text("Rest")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(timerManager.restDisplay)
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("Pomodoro")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        timerManager.start(seconds: 10 * 60)
                    } label: {
                        Text("10m")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        timerManager.start(seconds: 25 * 60)
                    } label: {
                        Text("25m")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }

                HStack(spacing: 8) {
                    Button {
                        timerManager.start(seconds: 45 * 60)
                    } label: {
                        Text("45m")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        timerManager.start(seconds: 60 * 60)
                    } label: {
                        Text("60m")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            }
        }
    }

    private var activeView: some View {
        VStack(spacing: 12) {
            Text(timerManager.state == .paused ? "Pause" : "\(timerManager.originalDuration / 60)-min session")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(timerManager.displayTime)
                .font(.system(size: 36, weight: .medium, design: .monospaced))
                .foregroundStyle(timerManager.state == .paused ? .secondary : .primary)

            HStack(spacing: 8) {
                Button {
                    timerManager.togglePause()
                } label: {
                    Text(timerManager.state == .paused ? "Resume" : "Pause")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    timerManager.reset()
                } label: {
                    Text("Reset")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
        }
    }

    private var completedView: some View {
        VStack(spacing: 12) {
            Text(timerManager.displayTime)
                .font(.system(size: 36, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            Button {
                timerManager.stop()
            } label: {
                Text("Stop")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
    }
}

/// Where a dragged row will land: before `beforeID`, or at the end of the
/// section when it is nil.
struct DropSlot: Equatable {
    let section: TodoSection
    let beforeID: UUID?
}

/// Frame of one row (or of a whole band, when `id` is nil) in the todo list's
/// coordinate space, used to hit test a drag.
struct TodoFrame: Equatable {
    let id: UUID?
    let section: TodoSection
    let rect: CGRect
}

struct TodoFrameKey: PreferenceKey {
    static var defaultValue: [TodoFrame] = []

    static func reduce(value: inout [TodoFrame], nextValue: () -> [TodoFrame]) {
        value.append(contentsOf: nextValue())
    }
}

extension TodoSection {
    /// Band background tint — kept low-opacity so the text stays legible.
    var tint: Color {
        switch self {
        case .goal: return .red
        case .main: return .yellow
        case .errand: return .green
        }
    }

    var emptyLabel: String {
        switch self {
        case .goal: return "Long-term goals (⌘⌥⌃[)"
        case .main: return "Today (⌘⌥⌃])"
        case .errand: return "Errands (⌘⌥⌃\\)"
        }
    }
}

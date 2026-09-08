import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var todayEditText: String = ""
    @FocusState private var isTodayFocused: Bool
    @State private var newTodoText: String = ""
    @State private var showResetTodayAlert: Bool = false
    @State private var draggingTodoID: UUID?

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
    }

    /// One tinted band of the list. The band itself is the drop target for the
    /// end of the section, so items can land in it even when it is empty.
    private func todoSection(_ section: TodoSection) -> some View {
        let items = timerManager.todos(in: section)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { todo in
                todoRow(todo)
                    .onDrag {
                        draggingTodoID = todo.id
                        return NSItemProvider(object: todo.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TodoDropDelegate(
                        targetID: todo.id,
                        section: section,
                        timerManager: timerManager,
                        draggingTodoID: $draggingTodoID))
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
        .contentShape(Rectangle())
        .onDrop(of: [.text], delegate: TodoDropDelegate(
            targetID: nil,
            section: section,
            timerManager: timerManager,
            draggingTodoID: $draggingTodoID))
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 6) {
            Text(todo.text)
                .font(.system(size: 11, weight: todo.section == .errand ? .regular : .bold))
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

/// Reorders live as the drag passes over a row (or over the band itself, where
/// `targetID` is nil and the item lands at the end of that section).
struct TodoDropDelegate: DropDelegate {
    let targetID: UUID?
    let section: TodoSection
    let timerManager: TimerManager
    @Binding var draggingTodoID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggingTodoID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggingTodoID, dragged != targetID else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            timerManager.moveTodo(dragged, before: targetID, section: section)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTodoID = nil
        return true
    }

    func dropExited(info: DropInfo) {}
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

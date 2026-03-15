import SwiftUI

struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var todayEditText: String = ""
    @FocusState private var isTodayFocused: Bool
    @State private var newTodoText: String = ""

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
            todoList
        }
        .padding(20)
        .frame(width: 220)
    }

    private func commitTodayEdit() {
        if let mins = Int(todayEditText) {
            timerManager.setTodayTotal(mins)
        }
        isTodayFocused = false
        todayEditText = timerManager.todayDisplay
    }

    private var todayField: some View {
        HStack(spacing: 4) {
            Text("Today:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("0", text: $todayEditText)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 50)
                .focused($isTodayFocused)
                .onAppear {
                    todayEditText = timerManager.todayDisplay
                }
                .onChange(of: isTodayFocused) { focused in
                    if focused {
                        todayEditText = "\(timerManager.todayTotalMinutes)"
                    } else {
                        commitTodayEdit()
                    }
                }
                .onChange(of: timerManager.todayTotalMinutes) { _ in
                    if !isTodayFocused {
                        todayEditText = timerManager.todayDisplay
                    }
                }
                .onSubmit {
                    commitTodayEdit()
                }
                .onExitCommand {
                    commitTodayEdit()
                }
        }
    }

    private var todoList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(timerManager.todos) { todo in
                HStack(spacing: 6) {
                    Text(todo.text)
                        .font(.system(size: 11))
                        .foregroundStyle(todo.isDone ? .secondary : .primary)
                        .strikethrough(todo.isDone)
                        .lineLimit(1)
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

    private var idleView: some View {
        VStack(spacing: 12) {
            if timerManager.restSeconds > 0 {
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
            Text("\(timerManager.originalDuration / 60)-min session")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(timerManager.displayTime)
                .font(.system(size: 36, weight: .medium, design: .monospaced))

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

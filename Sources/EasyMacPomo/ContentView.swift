import SwiftUI

struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var todayEditText: String = ""

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
        }
        .padding(20)
        .frame(width: 220)
    }

    private var todayField: some View {
        HStack(spacing: 4) {
            Text("Today:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("0m", text: $todayEditText)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 50)
                .onAppear {
                    todayEditText = timerManager.todayDisplay
                }
                .onChange(of: timerManager.todayTotalMinutes) { _ in
                    todayEditText = timerManager.todayDisplay
                }
                .onSubmit {
                    if let mins = Int(todayEditText) {
                        timerManager.todayMinutes = mins
                        todayEditText = timerManager.todayDisplay
                    } else {
                        todayEditText = timerManager.todayDisplay
                    }
                }
        }
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            Text("Pomodoro")
                .font(.headline)

            HStack(spacing: 8) {
                Button {
                    timerManager.start(seconds: 25 * 60)
                } label: {
                    Text("25m")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

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

    private var activeView: some View {
        VStack(spacing: 12) {
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
                .foregroundStyle(.green)

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

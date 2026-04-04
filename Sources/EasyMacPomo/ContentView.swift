import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var todayEditText: String = ""
    @FocusState private var isTodayFocused: Bool
    @State private var newTodoText: String = ""
    @State private var showResetTodayAlert: Bool = false

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

            exportButton
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
        VStack(alignment: .leading, spacing: 4) {
            ForEach(timerManager.todos) { todo in
                HStack(spacing: 6) {
                    Text(todo.text)
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

    private var pageName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "EasyMacPomo-\(formatter.string(from: Date()))"
    }

    private var exportButton: some View {
        Button {
            exportPDF()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 10))
                Text("Export PDF")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Export session summary as PDF")
    }

    private func exportPDF() {
        let pdfWidth: CGFloat = 400
        let margin: CGFloat = 30
        let contentWidth = pdfWidth - margin * 2
        var yOffset: CGFloat = margin

        let titleFont = NSFont.systemFont(ofSize: 18, weight: .bold)
        let headingFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let bodyColor = NSColor.labelColor
        let secondaryColor = NSColor.secondaryLabelColor

        // Pre-calculate content height
        var estimatedHeight: CGFloat = margin
        estimatedHeight += 30 // title
        estimatedHeight += 25 // date
        estimatedHeight += 30 // total time
        estimatedHeight += 30 // heading
        estimatedHeight += CGFloat(timerManager.todos.count) * 20
        if timerManager.todos.isEmpty { estimatedHeight += 20 }
        estimatedHeight += margin

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pdfWidth, height: estimatedHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        context.beginPDFPage(nil)

        // Flip coordinate system for natural top-down drawing
        context.translateBy(x: 0, y: estimatedHeight)
        context.scaleBy(x: 1, y: -1)

        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        // Title
        let title = pageName
        title.draw(at: NSPoint(x: margin, y: yOffset), withAttributes: [
            .font: titleFont, .foregroundColor: bodyColor
        ])
        yOffset += 28

        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateStr = dateFormatter.string(from: Date())
        dateStr.draw(at: NSPoint(x: margin, y: yOffset), withAttributes: [
            .font: bodyFont, .foregroundColor: secondaryColor
        ])
        yOffset += 22

        // Total time
        let totalStr = "Total: \(timerManager.sumDisplay)"
        totalStr.draw(at: NSPoint(x: margin, y: yOffset), withAttributes: [
            .font: headingFont, .foregroundColor: bodyColor
        ])
        yOffset += 28

        // Todos heading
        "Todos".draw(at: NSPoint(x: margin, y: yOffset), withAttributes: [
            .font: headingFont, .foregroundColor: bodyColor
        ])
        yOffset += 20

        // Todo items
        if timerManager.todos.isEmpty {
            "No todos".draw(at: NSPoint(x: margin, y: yOffset), withAttributes: [
                .font: bodyFont, .foregroundColor: secondaryColor
            ])
        } else {
            for todo in timerManager.todos {
                let prefix = todo.isDone ? "✓ " : "○ "
                let color = todo.isDone ? secondaryColor : bodyColor
                let text = NSAttributedString(string: "\(prefix)\(todo.text)", attributes: [
                    .font: bodyFont,
                    .foregroundColor: color,
                    .strikethroughStyle: todo.isDone ? NSUnderlineStyle.single.rawValue : 0
                ])
                text.draw(with: NSRect(x: margin, y: yOffset, width: contentWidth, height: 18), options: [.usesLineFragmentOrigin])
                yOffset += 18
            }
        }

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()

        // Show save panel with page name as default filename
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(pageName).pdf"
        savePanel.title = "Export PDF"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? pdfData.write(to: url, options: .atomic)
            }
        }
    }
}

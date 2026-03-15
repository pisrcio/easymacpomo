import AppKit
import SwiftUI

class TodoInputPanel {
    private var panel: NSPanel?
    private weak var timerManager: TimerManager?

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    func show() {
        if let panel = panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let timerManager = timerManager else { return }

        let inputView = TodoInputView(timerManager: timerManager) { [weak self] in
            self?.dismiss()
        }

        let hostingView = NSHostingView(rootView: inputView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 40)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "EasyMacPomo"
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Focus the text field after the panel is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            panel.makeFirstResponder(nil)
            panel.makeKeyAndOrderFront(nil)
        }

        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}

struct TodoInputView: View {
    @ObservedObject var timerManager: TimerManager
    var onDismiss: () -> Void
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Add todo...", text: $text)
            .font(.system(size: 14))
            .textFieldStyle(.plain)
            .padding(12)
            .focused($isFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isFocused = true
                }
            }
            .onSubmit {
                timerManager.addTodo(text)
                text = ""
                onDismiss()
            }
            .onExitCommand {
                text = ""
                onDismiss()
            }
    }
}

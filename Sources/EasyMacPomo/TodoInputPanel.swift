import AppKit
import SwiftUI

class TodoInputPanel {
    private var panel: NSPanel?
    private weak var timerManager: TimerManager?

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    func show() {
        if panel != nil {
            panel?.makeKeyAndOrderFront(nil)
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
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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
                isFocused = true
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

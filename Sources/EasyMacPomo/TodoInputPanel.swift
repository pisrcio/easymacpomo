import AppKit
import SwiftUI

class TodoInputPanel {
    private var panel: NSPanel?
    private weak var timerManager: TimerManager?
    private var currentSection: TodoSection = .errand

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    func show(section: TodoSection = .errand) {
        if let panel = panel {
            if section == currentSection {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            // Switching modes: rebuild the panel for the other section.
            dismiss()
        }

        guard let timerManager = timerManager else { return }
        currentSection = section

        let inputView = TodoInputView(timerManager: timerManager, section: section) { [weak self] in
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
        panel.title = "EasyMacPomo — \(section.title)"
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
    var section: TodoSection
    var onDismiss: () -> Void
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(section.placeholder, text: $text)
            .font(.system(size: 14))
            .textFieldStyle(.plain)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Same colour coding as the list bands, so the panel says which
            // section you are typing into.
            .background(section.tint.opacity(0.18))
            .overlay(
                Rectangle()
                    .stroke(section.tint.opacity(0.55), lineWidth: 2)
            )
            .focused($isFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isFocused = true
                }
            }
            .onSubmit {
                timerManager.addTodo(text, section: section)
                text = ""
                onDismiss()
            }
            .onExitCommand {
                text = ""
                onDismiss()
            }
    }
}

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        FocusManager.disableDoNotDisturb()
    }
}

@main
struct EasyMacPomoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var timerManager = TimerManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView(timerManager: timerManager)
        } label: {
            MenuBarIcon(state: timerManager.state)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarIcon: View {
    let state: TimerState

    var body: some View {
        switch state {
        case .idle:
            // Template image renders as white/black matching menu bar
            Image(nsImage: makeCircleIcon(color: nil))
        case .running:
            Image(nsImage: makeCircleIcon(color: .red))
        case .paused:
            Image(nsImage: makeCircleIcon(color: .yellow))
        case .completed:
            Image(nsImage: makeCircleIcon(color: .green))
        }
    }

    private func makeCircleIcon(color: NSColor?) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 2, dy: 2)

            if let color = color {
                // Colored fill for active states
                color.setFill()
                NSBezierPath(ovalIn: inset).fill()
            } else {
                // Filled circle for template rendering (white in dark menu bar)
                NSColor.black.setFill()
                NSBezierPath(ovalIn: inset).fill()
            }

            // Draw a small leaf/stem
            let stemPath = NSBezierPath()
            stemPath.move(to: NSPoint(x: rect.midX, y: inset.maxY))
            stemPath.curve(to: NSPoint(x: rect.midX + 4, y: rect.maxY),
                          controlPoint1: NSPoint(x: rect.midX, y: inset.maxY + 2),
                          controlPoint2: NSPoint(x: rect.midX + 2, y: rect.maxY))
            stemPath.lineWidth = 1.5
            if color != nil {
                NSColor.green.withAlphaComponent(0.8).setStroke()
            } else {
                NSColor.black.setStroke()
            }
            stemPath.stroke()

            return true
        }

        // Template mode makes macOS render it white on dark / black on light
        image.isTemplate = (color == nil)
        return image
    }
}

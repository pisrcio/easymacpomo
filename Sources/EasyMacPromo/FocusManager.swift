import Foundation

enum FocusManager {
    /// Enables "Reduced Interruptions" Focus mode via the Shortcuts app.
    ///
    /// Requires a Shortcut named "Start Reduced Interruptions" that enables
    /// the Focus mode. Create it in the Shortcuts app:
    /// 1. Open Shortcuts.app
    /// 2. Create a new shortcut named "Start Reduced Interruptions"
    /// 3. Add the "Set Focus" action → Turn On "Reduced Interruptions"
    static func enableReducedInterruptions() {
        runShortcut("Start Reduced Interruptions")
    }

    /// Disables "Reduced Interruptions" Focus mode via the Shortcuts app.
    ///
    /// Requires a Shortcut named "Stop Reduced Interruptions" that disables
    /// the Focus mode. Create it in the Shortcuts app:
    /// 1. Open Shortcuts.app
    /// 2. Create a new shortcut named "Stop Reduced Interruptions"
    /// 3. Add the "Set Focus" action → Turn Off "Reduced Interruptions"
    static func disableReducedInterruptions() {
        runShortcut("Stop Reduced Interruptions")
    }

    private static func runShortcut(_ name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        DispatchQueue.global(qos: .utility).async {
            try? process.run()
            process.waitUntilExit()
        }
    }
}

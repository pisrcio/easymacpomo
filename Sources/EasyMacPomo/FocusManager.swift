import Foundation

enum FocusManager {
    static func enableDoNotDisturb() {
        runShortcut("Turn On Do Not Disturb")
    }

    static func disableDoNotDisturb() {
        runShortcut("Turn Off Do Not Disturb")
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

import SwiftUI

@main
struct EasyMacPromoApp: App {
    @StateObject private var timerManager = TimerManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView(timerManager: timerManager)
        } label: {
            Text(timerManager.menuBarText)
        }
        .menuBarExtraStyle(.window)
    }
}

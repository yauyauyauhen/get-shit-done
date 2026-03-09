import SwiftUI

// MARK: - App Entry Point

@main
struct GetShitDoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — this is a menu bar-only app
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var appState: AppState!
    private var sessionManager: FocusSessionManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Initialize state
        appState = AppState()
        sessionManager = FocusSessionManager(appState: appState)

        // Set up menu bar (One Thing-inspired text display)
        menuBarController = MenuBarController(appState: appState, sessionManager: sessionManager)

        // Check permissions on launch
        appState.hasScreenPermission = ScreenCaptureService.shared.hasPermission
        Task {
            appState.hasNotificationPermission = await NotificationService.shared.requestPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        sessionManager?.stopSession()
    }
}

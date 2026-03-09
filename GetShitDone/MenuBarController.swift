import AppKit
import SwiftUI
import Combine

// MARK: - Menu Bar Controller
// Inspired by sindresorhus/one-thing (MIT License)
// Displays the current task as text in the macOS menu bar

final class MenuBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var appState: AppState

    init(appState: AppState, sessionManager: FocusSessionManager) {
        self.appState = appState
        // Create the status bar item with variable width to fit text
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(appState: appState, sessionManager: sessionManager)
        )

        // Configure the button
        if let button = statusItem.button {
            updateButton(button, task: appState.currentTask, isActive: appState.isSessionActive)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Subscribe to state changes
        appState.$currentTask
            .combineLatest(appState.$isSessionActive, appState.$menuBarMaxLength)
            .receive(on: RunLoop.main)
            .sink { [weak self] task, isActive, _ in
                guard let button = self?.statusItem.button else { return }
                self?.updateButton(button, task: task, isActive: isActive)
            }
            .store(in: &cancellables)
    }

    // MARK: - One Thing-style Menu Bar Text

    private func updateButton(_ button: NSStatusBarButton, task: String, isActive: Bool) {
        if task.isEmpty {
            button.title = ""
            button.image = NSImage(systemSymbolName: "target", accessibilityDescription: "Get Shit Done")
        } else {
            let maxLen = appState.menuBarMaxLength
            let displayText: String
            if maxLen == 0 || task.count <= maxLen {
                displayText = task
            } else {
                displayText = String(task.prefix(maxLen)) + "..."
            }

            // Add a focus indicator when session is active
            let prefix = isActive ? ">> " : ""
            button.title = " \(prefix)\(displayText)"
            button.image = NSImage(
                systemSymbolName: isActive ? "eye.fill" : "target",
                accessibilityDescription: "Get Shit Done"
            )
            button.imagePosition = .imageLeft
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Monitor for clicks outside the popover to dismiss it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

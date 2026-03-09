import SwiftUI

struct PopoverView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var sessionManager: FocusSessionManager
    @State private var showingSettings = false
    @State private var taskInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Task Input
                    taskSection

                    // Session Controls
                    sessionSection

                    // Status
                    if appState.isSessionActive {
                        statusSection
                    }

                    // Privacy notice
                    privacyNotice
                }
                .padding(16)
            }

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 340)
        .onAppear {
            taskInput = appState.currentTask
            checkPermissions()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "target")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Get Shit Done")
                .font(.headline)
            Spacer()
            if appState.isSessionActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Task Input

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Task")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField("What are you working on?", text: $taskInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    setTask()
                    if !appState.isSessionActive && canStartSession {
                        startSession()
                    }
                }
                .onChange(of: taskInput) { _ in setTask() }
                .disabled(appState.isSessionActive)
        }
    }

    // MARK: - Session Controls

    private var sessionSection: some View {
        VStack(spacing: 8) {
            if appState.isSessionActive {
                Button(action: { sessionManager.stopSession() }) {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop Focus Session")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)

                Button(action: { sessionManager.checkNow() }) {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("Check Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(appState.isChecking)
            } else {
                Button(action: { startSession() }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Focus Session")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canStartSession)
            }

            if !canStartSession && !appState.isSessionActive {
                startBlockerMessage
            }
        }
    }

    private var canStartSession: Bool {
        !appState.currentTask.isEmpty && appState.isConfigured
    }

    @ViewBuilder
    private var startBlockerMessage: some View {
        if appState.currentTask.isEmpty {
            Label("Enter a task first", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
        } else if !appState.isConfigured {
            Label("Configure API key in settings", systemImage: "key")
                .font(.caption)
                .foregroundColor(.orange)
        } else if !appState.hasScreenPermission {
            VStack(spacing: 4) {
                Label("Screen recording permission required", systemImage: "rectangle.dashed.badge.record")
                    .font(.caption)
                    .foregroundColor(.orange)
                Button("Grant Permission") {
                    ScreenCaptureService.shared.requestPermission()
                    // Re-check after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        appState.hasScreenPermission = ScreenCaptureService.shared.hasPermission
                    }
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Status")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                if appState.isChecking {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking focus...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    StatBadge(
                        label: "Checks",
                        value: "\(appState.sessionStats.checksCompleted)",
                        color: .green
                    )
                    StatBadge(
                        label: "Distractions",
                        value: "\(appState.sessionStats.distractionsDetected)",
                        color: .red
                    )
                    if let start = appState.sessionStats.startTime {
                        StatBadge(
                            label: "Duration",
                            value: formatDuration(since: start),
                            color: .white
                        )
                    }
                }

                if let result = appState.sessionStats.lastResult {
                    HStack(spacing: 4) {
                        Image(systemName: result.onTask ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.onTask ? .green : .red)
                        Text(result.reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(result.onTask ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
                }

                if let error = appState.lastError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
        }
    }

    // MARK: - Privacy Notice

    private var privacyNotice: some View {
        VStack(spacing: 4) {
            Divider()
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                Text("Screenshots are sent to \(appState.selectedProvider.rawValue) for analysis and are not stored.")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingSettings) {
                SettingsView(appState: appState)
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(12)
    }

    // MARK: - Actions

    private func setTask() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespaces)
        appState.currentTask = trimmed
    }

    private func startSession() {
        sessionManager.startSession()
    }

    private func checkPermissions() {
        appState.hasScreenPermission = ScreenCaptureService.shared.hasPermission
        Task {
            appState.hasNotificationPermission = await NotificationService.shared.checkPermission()
            if !appState.hasNotificationPermission {
                appState.hasNotificationPermission = await NotificationService.shared.requestPermission()
            }
        }
    }

    private func formatDuration(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}

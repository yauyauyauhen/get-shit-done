import Foundation
import Combine

final class FocusSessionManager: ObservableObject {
    private var timer: Timer?
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
    }

    func startSession() {
        guard !appState.currentTask.isEmpty else { return }
        guard appState.isConfigured else { return }

        appState.isSessionActive = true
        appState.sessionStats = SessionStats(startTime: Date())
        appState.lastError = nil

        NotificationService.shared.sendSessionStartNotification(task: appState.currentTask)

        scheduleTimer()

        // Run first check after a short delay (30 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.appState.isSessionActive else { return }
            Task { await self.performCheck() }
        }
    }

    func checkNow() {
        Task { await performCheck() }
    }

    func stopSession() {
        timer?.invalidate()
        timer = nil
        appState.isSessionActive = false
        appState.isChecking = false
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: appState.checkInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.performCheck() }
        }
    }

    @MainActor
    private func performCheck() async {
        guard !appState.isChecking else { return } // prevent overlapping checks
        guard appState.isSessionActive else { return }
        guard let apiKey = appState.apiKey, !apiKey.isEmpty else {
            appState.lastError = "No API key configured"
            return
        }

        appState.isChecking = true

        do {
            // Run the check with a 90-second timeout
            let result = try await withTimeout(seconds: 90) {
                try await self.doCheck(apiKey: apiKey)
            }

            appState.sessionStats.checksCompleted += 1
            appState.sessionStats.lastCheckTime = Date()
            appState.sessionStats.lastResult = result
            appState.lastError = nil

            if !result.onTask && result.confidence >= appState.confidenceThreshold {
                appState.sessionStats.distractionsDetected += 1
                NotificationService.shared.sendDistractedNotification(
                    task: appState.currentTask,
                    reason: result.reason
                )
            }

        } catch {
            appState.lastError = error.localizedDescription
            print("Focus check failed: \(error)")
        }

        appState.isChecking = false
    }

    private func doCheck(apiKey: String) async throws -> FocusCheckResult {
        guard ScreenCaptureService.shared.hasPermission else {
            await MainActor.run {
                appState.hasScreenPermission = false
            }
            throw ScreenCaptureError.permissionDenied
        }

        let imageData = try await ScreenCaptureService.shared.captureScreen()

        let provider = LLMProviderFactory.create(
            type: appState.selectedProvider,
            apiKey: apiKey,
            model: appState.selectedModel
        )

        return try await provider.evaluateScreenshot(
            imageData: imageData,
            task: appState.currentTask
        )
    }
}

// MARK: - Timeout helper

func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw LLMError.networkError(URLError(.timedOut))
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

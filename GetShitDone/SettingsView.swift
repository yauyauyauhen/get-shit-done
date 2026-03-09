import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var apiKeyInput: String = ""
    @State private var showApiKey: Bool = false
    @State private var savedMessage: String?
    @State private var intervalMinutes: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }
            .padding(12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    providerSection
                    modelSection
                    apiKeySection
                    menuBarLengthSection
                    intervalSection
                    thresholdSection
                    permissionsSection
                    privacySection
                }
                .padding(16)
            }
        }
        .frame(width: 340, height: 520)
        .onAppear {
            apiKeyInput = appState.apiKey ?? ""
            intervalMinutes = max(1, Int(appState.checkInterval / 60))
        }
    }

    // MARK: - Provider

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Provider")
                .font(.subheadline)
                .fontWeight(.medium)
            Picker("", selection: $appState.selectedProvider) {
                ForEach(LLMProviderType.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appState.selectedProvider) { newValue in
                apiKeyInput = appState.apiKey ?? ""
                appState.selectedModel = newValue.defaultModel
            }
        }
    }

    // MARK: - Model Picker

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("", selection: $appState.selectedModel) {
                ForEach(appState.selectedProvider.availableModels, id: \.id) { model in
                    Text(model.label).tag(model.id)
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(showApiKey ? "Hide" : "Show") {
                    showApiKey.toggle()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }

            HStack {
                if showApiKey {
                    TextField("sk-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                } else {
                    SecureField("sk-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                }

                Button("Save") {
                    appState.setApiKey(apiKeyInput)
                    savedMessage = "Saved"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        savedMessage = nil
                    }
                }
                .disabled(apiKeyInput.isEmpty)
            }

            if let msg = savedMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Text("Stored securely in macOS Keychain")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Menu Bar Length

    private var menuBarLengthSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu Bar Preview Length")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Text(appState.menuBarMaxLength == 0 ? "Max (full text)" : "\(appState.menuBarMaxLength) characters")
                    .monospacedDigit()
                Spacer()
                Stepper("", value: Binding(
                    get: { appState.menuBarMaxLength },
                    set: { newValue in
                        if newValue < 10 {
                            appState.menuBarMaxLength = 0 // wrap to "max"
                        } else {
                            appState.menuBarMaxLength = newValue
                        }
                    }
                ), in: 0...100, step: 5)
                    .labelsHidden()
            }

            Text("0 = show full task text in menu bar")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Check Interval (Stepper)

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Check Interval")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Text(intervalMinutes == 1 ? "1 minute" : "\(intervalMinutes) minutes")
                    .monospacedDigit()
                Spacer()
                Stepper("", value: $intervalMinutes, in: 1...30)
                    .labelsHidden()
                    .onChange(of: intervalMinutes) { newValue in
                        appState.checkInterval = Double(newValue) * 60
                    }
            }
        }
    }

    // MARK: - Confidence Threshold

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Confidence Threshold")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.0f%%", appState.confidenceThreshold * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $appState.confidenceThreshold,
                in: 0.5...1.0,
                step: 0.05
            )
            Text("Only notify when model is at least this confident you're distracted")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Image(systemName: appState.hasScreenPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(appState.hasScreenPermission ? .green : .red)
                Text("Screen Recording")
                Spacer()
                if !appState.hasScreenPermission {
                    Button("Grant") {
                        ScreenCaptureService.shared.requestPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            appState.hasScreenPermission = ScreenCaptureService.shared.hasPermission
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !appState.hasScreenPermission {
                Text("Required to capture screenshots for focus checking.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Image(systemName: appState.hasNotificationPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(appState.hasNotificationPermission ? .green : .red)
                Text("Notifications")
                Spacer()
                if !appState.hasNotificationPermission {
                    Button("Grant") {
                        Task {
                            appState.hasNotificationPermission = await NotificationService.shared.requestPermission()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !appState.hasNotificationPermission {
                Text("Required to alert you when you appear distracted.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Privacy Notice

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Privacy")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Screenshots are captured periodically during active sessions and sent to your chosen LLM provider (\(appState.selectedProvider.rawValue)) for analysis. Screenshots are never stored locally or remotely by Get Shit Done. Your API key is stored securely in the macOS Keychain.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

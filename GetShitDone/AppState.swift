import Foundation
import Combine

final class AppState: ObservableObject {
    // MARK: - Task State
    @Published var currentTask: String {
        didSet { UserDefaults.standard.set(currentTask, forKey: "currentTask") }
    }

    // MARK: - Session State
    @Published var isSessionActive: Bool = false
    @Published var sessionStats: SessionStats = SessionStats()
    @Published var lastError: String?
    @Published var isChecking: Bool = false

    // MARK: - Settings
    @Published var selectedProvider: LLMProviderType {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider") }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var checkInterval: TimeInterval {
        didSet { UserDefaults.standard.set(checkInterval, forKey: "checkInterval") }
    }
    @Published var confidenceThreshold: Double {
        didSet { UserDefaults.standard.set(confidenceThreshold, forKey: "confidenceThreshold") }
    }
    /// 0 means "max" (no truncation)
    @Published var menuBarMaxLength: Int {
        didSet { UserDefaults.standard.set(menuBarMaxLength, forKey: "menuBarMaxLength") }
    }

    // MARK: - Permission State
    @Published var hasScreenPermission: Bool = false
    @Published var hasNotificationPermission: Bool = false

    init() {
        self.currentTask = UserDefaults.standard.string(forKey: "currentTask") ?? ""

        if let providerRaw = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = LLMProviderType(rawValue: providerRaw) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .openai
        }

        let savedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? ""
        self.selectedModel = savedModel.isEmpty ? LLMProviderType.openai.defaultModel : savedModel

        let savedInterval = UserDefaults.standard.double(forKey: "checkInterval")
        self.checkInterval = savedInterval > 0 ? savedInterval : 300 // 5 minutes default

        let savedThreshold = UserDefaults.standard.double(forKey: "confidenceThreshold")
        self.confidenceThreshold = savedThreshold > 0 ? savedThreshold : 0.7

        let savedMaxLen = UserDefaults.standard.integer(forKey: "menuBarMaxLength")
        self.menuBarMaxLength = savedMaxLen > 0 ? savedMaxLen : 30 // default 30, 0 = max
    }

    var apiKey: String? {
        KeychainService.shared.retrieve(key: selectedProvider.keychainKey)
    }

    var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty && !selectedModel.isEmpty
    }

    func setApiKey(_ key: String) {
        try? KeychainService.shared.save(key: selectedProvider.keychainKey, value: key)
        objectWillChange.send()
    }
}

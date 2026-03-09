import Foundation

// MARK: - Focus Check Result

struct FocusCheckResult: Codable {
    let onTask: Bool
    let confidence: Double
    let reason: String

    enum CodingKeys: String, CodingKey {
        case onTask = "on_task"
        case confidence
        case reason
    }
}

// MARK: - LLM Provider Type

enum LLMProviderType: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case openRouter = "OpenRouter"

    var id: String { rawValue }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-5.2"
        case .anthropic: return "claude-sonnet-4-5-20250514"
        case .openRouter: return "openai/gpt-4o"
        }
    }

    var availableModels: [(id: String, label: String)] {
        switch self {
        case .openai:
            return [
                ("gpt-5.4", "GPT-5.4"),
                ("gpt-5.3-chat-latest", "GPT-5.3 Instant"),
                ("gpt-5.2", "GPT-5.2"),
                ("gpt-4.1", "GPT-4.1"),
                ("gpt-4.1-mini", "GPT-4.1 Mini"),
                ("gpt-4.1-nano", "GPT-4.1 Nano"),
                ("gpt-4o", "GPT-4o"),
                ("gpt-4o-mini", "GPT-4o Mini"),
                ("o4-mini", "o4-mini"),
                ("o3", "o3"),
                ("o3-mini", "o3-mini"),
            ]
        case .anthropic:
            return [
                ("claude-opus-4-6", "Claude Opus 4.6"),
                ("claude-sonnet-4-6", "Claude Sonnet 4.6"),
                ("claude-haiku-4-5-20251001", "Claude Haiku 4.5"),
                ("claude-sonnet-4-5", "Claude Sonnet 4.5"),
                ("claude-opus-4-5", "Claude Opus 4.5"),
                ("claude-opus-4-1", "Claude Opus 4.1"),
                ("claude-sonnet-4-0", "Claude Sonnet 4"),
            ]
        case .openRouter:
            return [
                ("openai/gpt-5.4", "GPT-5.4"),
                ("openai/gpt-5.3-chat-latest", "GPT-5.3 Instant"),
                ("openai/gpt-5.2", "GPT-5.2"),
                ("anthropic/claude-opus-4-6", "Claude Opus 4.6"),
                ("anthropic/claude-sonnet-4-6", "Claude Sonnet 4.6"),
                ("anthropic/claude-haiku-4-5-20251001", "Claude Haiku 4.5"),
                ("openai/gpt-4.1", "GPT-4.1"),
                ("openai/gpt-4o", "GPT-4o"),
                ("google/gemini-2.5-pro", "Gemini 2.5 Pro"),
            ]
        }
    }

    var keychainKey: String {
        switch self {
        case .openai: return "com.getshitdone.apikey.openai"
        case .anthropic: return "com.getshitdone.apikey.anthropic"
        case .openRouter: return "com.getshitdone.apikey.openrouter"
        }
    }
}

// MARK: - Session Stats

struct SessionStats {
    var startTime: Date?
    var checksCompleted: Int = 0
    var distractionsDetected: Int = 0
    var lastCheckTime: Date?
    var lastResult: FocusCheckResult?
}

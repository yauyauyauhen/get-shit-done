import Foundation

// MARK: - LLM Provider Protocol

protocol LLMProvider {
    func evaluateScreenshot(imageData: Data, task: String) async throws -> FocusCheckResult
}

// MARK: - Provider Errors

enum LLMError: Error, LocalizedError {
    case noApiKey
    case invalidResponse
    case httpError(Int, String)
    case jsonParsingFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "No API key configured"
        case .invalidResponse: return "Invalid response from LLM"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .jsonParsingFailed(let detail): return "Failed to parse LLM response: \(detail)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Focus Evaluation Prompt

enum FocusPrompt {
    static func buildPrompt(task: String) -> String {
        """
        You are a focus monitor. The user declared they are working on a SPECIFIC task. Your job is to determine whether the screen shows work on THAT EXACT task — not just "productive work" in general.

        Declared task: "\(task)"

        Carefully read the screenshot. Pay close attention to:
        - File names, tab titles, window titles
        - The actual code, text, or content visible on screen
        - Browser tabs and URLs
        - Which project or feature the visible work relates to
        - Terminal commands and their context

        IMPORTANT: Working on a DIFFERENT project, feature, or task still counts as OFF-TASK, even if it looks productive. The question is not "are they working?" but "are they working on THIS SPECIFIC thing?"

        Examples of off-task:
        - Task is "Fix editor alignment bug" but screen shows work on a database migration
        - Task is "Write unit tests for auth" but screen shows UI design work
        - Task is "Review PR #42" but screen shows writing new code unrelated to that PR
        - Social media, entertainment, unrelated browsing

        Examples of on-task:
        - Screen shows code/files/docs directly related to the declared task
        - Researching something clearly needed for the declared task
        - Testing or debugging the specific feature mentioned in the task

        If you cannot read enough detail to tell, or if it's ambiguous, lean toward on-task.

        Respond ONLY with valid JSON (no markdown, no code fences):
        {"on_task": true or false, "confidence": 0.0 to 1.0, "reason": "brief explanation of what you see and why it does or doesn't match the task"}
        """
    }
}

// MARK: - Provider Factory

enum LLMProviderFactory {
    static func create(type: LLMProviderType, apiKey: String, model: String) -> LLMProvider {
        switch type {
        case .openai:
            return OpenAICompatibleProvider(
                apiKey: apiKey,
                model: model,
                endpoint: "https://api.openai.com/v1/chat/completions"
            )
        case .anthropic:
            return AnthropicProvider(apiKey: apiKey, model: model)
        case .openRouter:
            return OpenAICompatibleProvider(
                apiKey: apiKey,
                model: model,
                endpoint: "https://openrouter.ai/api/v1/chat/completions"
            )
        }
    }
}

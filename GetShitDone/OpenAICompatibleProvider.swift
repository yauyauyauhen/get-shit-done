import Foundation

/// Handles OpenAI and OpenRouter APIs (same format, different endpoints)
struct OpenAICompatibleProvider: LLMProvider {
    let apiKey: String
    let model: String
    let endpoint: String

    func evaluateScreenshot(imageData: Data, task: String) async throws -> FocusCheckResult {
        let base64Image = imageData.base64EncodedString()
        let prompt = FocusPrompt.buildPrompt(task: task)

        // GPT-5.x uses max_completion_tokens; older models use max_tokens
        let needsNewTokenKey = model.hasPrefix("gpt-5") || model.hasPrefix("o3") || model.hasPrefix("o4")
        let tokenKey = needsNewTokenKey ? "max_completion_tokens" : "max_tokens"

        let requestBody: [String: Any] = [
            "model": model,
            tokenKey: 256,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.httpError(httpResponse.statusCode, body)
        }

        return try parseOpenAIResponse(data)
    }

    private func parseOpenAIResponse(_ data: Data) throws -> FocusCheckResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return try parseJSONContent(content)
    }
}

// MARK: - Shared JSON Parsing

func parseJSONContent(_ content: String) throws -> FocusCheckResult {
    // Strip markdown code fences if present
    var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.hasPrefix("```json") {
        cleaned = String(cleaned.dropFirst(7))
    } else if cleaned.hasPrefix("```") {
        cleaned = String(cleaned.dropFirst(3))
    }
    if cleaned.hasSuffix("```") {
        cleaned = String(cleaned.dropLast(3))
    }
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let jsonData = cleaned.data(using: .utf8) else {
        throw LLMError.jsonParsingFailed("Could not convert to data")
    }

    do {
        let result = try JSONDecoder().decode(FocusCheckResult.self, from: jsonData)
        return result
    } catch {
        throw LLMError.jsonParsingFailed("Raw content: \(cleaned)")
    }
}

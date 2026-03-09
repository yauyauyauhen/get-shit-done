import Foundation

struct AnthropicProvider: LLMProvider {
    let apiKey: String
    let model: String
    private let endpoint = "https://api.anthropic.com/v1/messages"

    func evaluateScreenshot(imageData: Data, task: String) async throws -> FocusCheckResult {
        let base64Image = imageData.base64EncodedString()
        let prompt = FocusPrompt.buildPrompt(task: task)

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
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
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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

        return try parseAnthropicResponse(data)
    }

    private func parseAnthropicResponse(_ data: Data) throws -> FocusCheckResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let firstBlock = contentArray.first,
              let text = firstBlock["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return try parseJSONContent(text)
    }
}

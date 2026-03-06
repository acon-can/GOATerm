import Foundation

enum ClaudeAPIError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured"
        case .invalidResponse: return "Invalid response from API"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        }
    }
}

final class ClaudeAPIService {
    static let shared = ClaudeAPIService()
    private var model: String { PreferencesManager.shared.chatModel }
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private init() {}

    func sendMessage(
        messages: [(role: String, content: String, imageData: Data?, imageMediaType: String?)],
        systemPrompt: String? = nil,
        onToken: @escaping (String) -> Void
    ) async throws {
        guard let apiKey = APIKeyManager.load() else {
            throw ClaudeAPIError.noAPIKey
        }

        let apiMessages: [[String: Any]] = messages.map { msg in
            if let fileData = msg.imageData, let mediaType = msg.imageMediaType {
                var contentBlocks: [[String: Any]]
                if mediaType == "application/pdf" {
                    contentBlocks = [
                        [
                            "type": "document",
                            "source": [
                                "type": "base64",
                                "media_type": mediaType,
                                "data": fileData.base64EncodedString()
                            ]
                        ]
                    ]
                } else {
                    contentBlocks = [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mediaType,
                                "data": fileData.base64EncodedString()
                            ]
                        ]
                    ]
                }
                if !msg.content.isEmpty {
                    contentBlocks.append(["type": "text", "text": msg.content])
                }
                return ["role": msg.role, "content": contentBlocks] as [String: Any]
            }
            return ["role": msg.role, "content": msg.content] as [String: Any]
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "messages": apiMessages
        ]
        if let sys = systemPrompt {
            body["system"] = sys
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw ClaudeAPIError.httpError(httpResponse.statusCode, errorBody)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let json = String(line.dropFirst(6))
            guard json != "[DONE]",
                  let data = json.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let delta = event["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                onToken(text)
            }
        }
    }
}

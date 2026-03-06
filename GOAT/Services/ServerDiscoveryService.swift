import Foundation

final class ServerDiscoveryService {
    static let shared = ServerDiscoveryService()

    private init() {}

    @MainActor
    func discoverServers(in directory: String, store: ServerStore) async {
        store.discoveryStatus = .scanning
        store.currentDirectory = directory

        let readmePath = (directory as NSString).appendingPathComponent("README.md")
        guard FileManager.default.fileExists(atPath: readmePath),
              let readmeContent = try? String(contentsOfFile: readmePath, encoding: .utf8) else {
            store.discoveryStatus = .noReadme
            return
        }

        let systemPrompt = """
        You are a dev tool assistant. Given a README.md file, extract all development server commands \
        (e.g. npm run dev, yarn start, python manage.py runserver, cargo watch, etc.).

        Return ONLY a JSON array of objects with "name" and "command" fields. Example:
        [{"name":"Frontend","command":"npm run dev"},{"name":"Backend","command":"python manage.py runserver"}]

        If no server/dev commands are found, return an empty array: []
        Do not include build commands, test commands, or one-off scripts — only long-running dev servers.
        Return raw JSON only, no markdown fences, no explanation.
        """

        let messages: [(role: String, content: String, attachments: [ChatAttachment])] = [
            (role: "user", content: readmeContent, attachments: [])
        ]

        var fullResponse = ""

        do {
            try await ClaudeAPIService.shared.sendMessage(
                messages: messages,
                systemPrompt: systemPrompt,
                onToken: { token in
                    fullResponse += token
                }
            )

            let servers = parseServerList(from: fullResponse)
            store.setDiscoveredServers(servers)
        } catch {
            store.discoveryStatus = .error(error.localizedDescription)
        }
    }

    private func parseServerList(from response: String) -> [(name: String, command: String)] {
        // Strip markdown fences if present
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            // Remove opening fence line
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            // Remove closing fence
            if let lastFence = cleaned.range(of: "```", options: .backwards) {
                cleaned = String(cleaned[..<lastFence.lowerBound])
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find JSON array boundaries
        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else {
            return []
        }

        let jsonString = String(cleaned[start...end])
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }

        return array.compactMap { dict in
            guard let name = dict["name"], let command = dict["command"] else { return nil }
            return (name: name, command: command)
        }
    }
}

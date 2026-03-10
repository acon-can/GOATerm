import Foundation

final class ChatFileService {
    static let shared = ChatFileService()
    private init() {}

    private let fileName = "chat-history.goat.md"
    private let saveQueue = DispatchQueue(label: "dev.getGOAT.chathistory.save")

    // MARK: - Load

    func load(from directory: String) -> [ChatMessage] {
        let filePath = (directory as NSString).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: filePath),
              let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return parse(content)
    }

    // MARK: - Save

    func save(_ messages: [ChatMessage], to directory: String) {
        let content = serialize(messages)
        let hasContent = !messages.isEmpty

        saveQueue.async { [self] in
            let filePath = (directory as NSString).appendingPathComponent(fileName)
            if !hasContent {
                try? FileManager.default.removeItem(atPath: filePath)
                return
            }
            if let data = content.data(using: .utf8) {
                let url = URL(fileURLWithPath: filePath)
                try? data.write(to: url, options: .atomic)
            }
            self.updateGitignore(in: directory)
        }
    }

    // MARK: - .gitignore

    func updateGitignore(in directory: String) {
        let gitignorePath = (directory as NSString).appendingPathComponent(".gitignore")
        let gitDir = (directory as NSString).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir) else { return }

        let shouldIgnore = PreferencesManager.shared.gitignoreChatHistory

        var lines: [String] = []
        if let data = FileManager.default.contents(atPath: gitignorePath),
           let existing = String(data: data, encoding: .utf8) {
            lines = existing.components(separatedBy: .newlines)
        }

        let alreadyIgnored = lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == fileName })

        if shouldIgnore && !alreadyIgnored {
            if let last = lines.last, last.isEmpty {
                lines.insert(fileName, at: lines.count - 1)
            } else {
                lines.append(fileName)
            }
            let result = lines.joined(separator: "\n")
            if let data = result.data(using: .utf8) {
                try? data.write(to: URL(fileURLWithPath: gitignorePath), options: .atomic)
            }
        } else if !shouldIgnore && alreadyIgnored {
            lines.removeAll { $0.trimmingCharacters(in: .whitespaces) == fileName }
            let result = lines.joined(separator: "\n")
            if let data = result.data(using: .utf8) {
                try? data.write(to: URL(fileURLWithPath: gitignorePath), options: .atomic)
            }
        }
    }

    // MARK: - Parser

    private func parse(_ content: String) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        let lines = content.components(separatedBy: .newlines)

        var currentRole: ChatRole?
        var currentTimestamp: Date?
        var currentLines: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for line in lines {
            // Match role headers: "### user [2026-03-10 14:30]" or "### assistant [...]"
            if line.hasPrefix("### user ") || line.hasPrefix("### assistant ") {
                // Flush previous message
                if let role = currentRole {
                    let text = currentLines.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        messages.append(ChatMessage(
                            role: role,
                            content: text,
                            timestamp: currentTimestamp ?? Date()
                        ))
                    }
                }

                // Parse new header
                let isUser = line.hasPrefix("### user")
                currentRole = isUser ? .user : .assistant
                currentLines = []

                // Extract timestamp from brackets
                if let open = line.firstIndex(of: "["),
                   let close = line.firstIndex(of: "]") {
                    let dateStr = String(line[line.index(after: open)..<close])
                    currentTimestamp = dateFormatter.date(from: dateStr) ?? Date()
                } else {
                    currentTimestamp = Date()
                }
                continue
            }

            // Skip header/comment lines
            if line.hasPrefix("<!--") || line.hasPrefix("-->") || line.hasPrefix("# ") {
                continue
            }

            if currentRole != nil {
                currentLines.append(line)
            }
        }

        // Flush last message
        if let role = currentRole {
            let text = currentLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                messages.append(ChatMessage(
                    role: role,
                    content: text,
                    timestamp: currentTimestamp ?? Date()
                ))
            }
        }

        return messages
    }

    // MARK: - Serializer

    private func serialize(_ messages: [ChatMessage]) -> String {
        var lines: [String] = []

        lines.append("<!--")
        lines.append("  chat-history.goat.md — Chat history managed by GOAT.")
        lines.append("  https://getGOAT.dev")
        lines.append("")
        lines.append("  This file is auto-generated. You can also edit it by hand.")
        lines.append("-->")
        lines.append("")
        lines.append("# Chat History")
        lines.append("")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for message in messages {
            let timestamp = dateFormatter.string(from: message.timestamp)
            lines.append("### \(message.role.rawValue) [\(timestamp)]")
            lines.append("")
            lines.append(message.content)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

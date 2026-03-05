import Foundation

final class ClaudeCodeHistoryService {
    static let shared = ClaudeCodeHistoryService()

    private let claudeDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent(".claude/projects")
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {}

    // MARK: - Public

    func loadHistory(directory: String) -> [PromptEntry] {
        let sessionFiles = findSessionFiles(for: directory)
        var entries: [PromptEntry] = []
        for path in sessionFiles {
            entries.append(contentsOf: parseUserPrompts(from: path))
        }
        return entries
    }

    // MARK: - Directory Encoding

    func encodeDirectoryPath(_ path: String) -> String {
        return path.replacingOccurrences(of: "/", with: "-")
    }

    // MARK: - Find Session Files

    func findSessionFiles(for directory: String) -> [String] {
        let encoded = encodeDirectoryPath(directory)
        let indexPath = (claudeDir as NSString)
            .appendingPathComponent(encoded)
            .appending("/sessions-index.json")

        guard let data = FileManager.default.contents(atPath: indexPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entries"] as? [[String: Any]] else {
            return []
        }

        var paths: [String] = []
        for entry in entries {
            guard let projectPath = entry["projectPath"] as? String,
                  projectPath == directory,
                  let fullPath = entry["fullPath"] as? String else {
                continue
            }
            if FileManager.default.fileExists(atPath: fullPath) {
                paths.append(fullPath)
            }
        }
        return paths
    }

    // MARK: - Parse User Prompts

    func parseUserPrompts(from filePath: String) -> [PromptEntry] {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var entries: [PromptEntry] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let lineData = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            guard let type = obj["type"] as? String, type == "user" else { continue }

            guard let message = obj["message"] as? [String: Any],
                  let contentValue = message["content"] else { continue }

            // Only keep string content (not arrays, which are tool results)
            guard let promptText = contentValue as? String else { continue }

            // Skip system/command messages
            let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPrompt.isEmpty { continue }
            if trimmedPrompt.hasPrefix("<local-command-") { continue }
            if trimmedPrompt.hasPrefix("<command-name>") { continue }
            if trimmedPrompt.hasPrefix("<local-command-stdout>") { continue }
            if trimmedPrompt.hasPrefix("<task-notification>") { continue }
            if trimmedPrompt.hasPrefix("This session is being continued from a previous conversation") { continue }

            let timestamp: Date
            if let ts = obj["timestamp"] as? String {
                timestamp = isoFormatter.date(from: ts)
                    ?? isoFormatterNoFrac.date(from: ts)
                    ?? Date()
            } else {
                timestamp = Date()
            }

            entries.append(PromptEntry(
                id: UUID(),
                timestamp: timestamp,
                prompt: trimmedPrompt,
                source: .claudeCode
            ))
        }

        return entries
    }
}

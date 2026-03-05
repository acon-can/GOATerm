import Foundation

enum PromptSource {
    case chat
    case claudeCode
}

struct PromptEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let prompt: String
    var source: PromptSource = .chat
}

final class PromptHistoryService {
    static let shared = PromptHistoryService()
    private let fileName = "history.goat.md"

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df
    }()

    private init() {}

    // MARK: - Add Prompt

    func addPrompt(_ prompt: String, directory: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let filePath = (directory as NSString).appendingPathComponent(fileName)
        let timestamp = dateFormatter.string(from: Date())
        let entry = "- [\(timestamp)] \(trimmed)\n"

        if FileManager.default.fileExists(atPath: filePath) {
            if let handle = FileHandle(forWritingAtPath: filePath) {
                handle.seekToEndOfFile()
                if let data = entry.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        } else {
            let header = "# Prompt History\n\n"
            let content = header + entry
            if let data = content.data(using: .utf8) {
                FileManager.default.createFile(atPath: filePath, contents: data)
            }
        }
    }

    // MARK: - Load History

    func loadHistory(directory: String) -> [PromptEntry] {
        let filePath = (directory as NSString).appendingPathComponent(fileName)
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8),
              !content.isEmpty else {
            return []
        }

        var entries: [PromptEntry] = []
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- [") else { continue }

            // Parse: - [2026-03-03 14:30] prompt text here
            let afterDash = String(trimmed.dropFirst(2))  // drop "- "
            guard let closeBracket = afterDash.firstIndex(of: "]") else { continue }
            let dateString = String(afterDash[afterDash.index(after: afterDash.startIndex)..<closeBracket])
            let promptText = String(afterDash[afterDash.index(after: closeBracket)...])
                .trimmingCharacters(in: .whitespaces)

            let date = dateFormatter.date(from: dateString) ?? Date()
            guard !promptText.isEmpty else { continue }
            entries.append(PromptEntry(id: UUID(), timestamp: date, prompt: promptText))
        }

        return entries.reversed()  // Most recent first
    }

    // MARK: - Load All History (Chat + Claude Code)

    func loadAllHistory(directory: String) -> [PromptEntry] {
        let chatEntries = loadHistory(directory: directory)
        let claudeEntries = ClaudeCodeHistoryService.shared.loadHistory(directory: directory)
        let merged = (chatEntries + claudeEntries).sorted { $0.timestamp > $1.timestamp }
        return merged
    }

    // MARK: - Copy All

    func copyAllText(directory: String) -> String {
        let entries = loadAllHistory(directory: directory)
        return entries.reversed().map { "- \($0.prompt)" }.joined(separator: "\n")
    }
}

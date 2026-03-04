import Foundation

struct PromptEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let prompt: String
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
            try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Load History

    func loadHistory(directory: String) -> [PromptEntry] {
        let filePath = (directory as NSString).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: filePath),
              let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }

        var entries: [PromptEntry] = []
        for line in content.components(separatedBy: "\n") {
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

    // MARK: - Copy All

    func copyAllText(directory: String) -> String {
        let entries = loadHistory(directory: directory)
        return entries.reversed().map { "- \($0.prompt)" }.joined(separator: "\n")
    }
}

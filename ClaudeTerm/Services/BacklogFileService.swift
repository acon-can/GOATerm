import Foundation

final class BacklogFileService {
    static let shared = BacklogFileService()
    private init() {}

    private let fileName = "backlog.goat.md"

    // MARK: - Load

    func load(from directory: String) -> BacklogStore {
        let filePath = (directory as NSString).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: filePath),
              let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let store = BacklogStore()
            store.directory = directory
            return store
        }

        let store = parse(content)
        store.directory = directory
        return store
    }

    // MARK: - Save

    func save(_ store: BacklogStore) {
        guard let directory = store.directory else { return }
        let filePath = (directory as NSString).appendingPathComponent(fileName)
        let content = serialize(store)

        // Don't write empty backlogs — delete the file if it exists
        let hasContent = store.featureBoards.contains { !$0.bullets.isEmpty }
            || store.bugBoards.contains { !$0.bullets.isEmpty }
        if !hasContent {
            try? FileManager.default.removeItem(atPath: filePath)
            return
        }

        if let data = content.data(using: .utf8) {
            let url = URL(fileURLWithPath: filePath)
            try? data.write(to: url, options: .atomic)
        }
        updateGitignore(in: directory)
    }

    // MARK: - .gitignore

    /// Adds or removes `backlog.goat.md` from the project's `.gitignore`
    /// based on the user's preference.
    func updateGitignore(in directory: String) {
        let gitignorePath = (directory as NSString).appendingPathComponent(".gitignore")
        let entry = fileName

        // Only manage .gitignore in directories that are git repos
        let gitDir = (directory as NSString).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir) else { return }

        let shouldIgnore = PreferencesManager.shared.gitignoreBacklog

        var lines: [String] = []
        if let data = FileManager.default.contents(atPath: gitignorePath),
           let existing = String(data: data, encoding: .utf8) {
            lines = existing.components(separatedBy: .newlines)
        }

        let alreadyIgnored = lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == entry })

        if shouldIgnore && !alreadyIgnored {
            // Add entry
            if let last = lines.last, last.isEmpty {
                lines.insert(entry, at: lines.count - 1)
            } else {
                lines.append(entry)
            }
            let result = lines.joined(separator: "\n")
            if let data = result.data(using: .utf8) {
                try? data.write(to: URL(fileURLWithPath: gitignorePath), options: .atomic)
            }
        } else if !shouldIgnore && alreadyIgnored {
            // Remove entry
            lines.removeAll { $0.trimmingCharacters(in: .whitespaces) == entry }
            let result = lines.joined(separator: "\n")
            if let data = result.data(using: .utf8) {
                try? data.write(to: URL(fileURLWithPath: gitignorePath), options: .atomic)
            }
        }
    }

    // MARK: - Parser

    private func parse(_ content: String) -> BacklogStore {
        var featureBoards: [KanbanBoard] = []
        var bugBoards: [KanbanBoard] = []
        var currentCategory: BacklogCategory?
        var currentBoard: KanbanBoard?
        var currentColor: TerminalColor = .default

        let lines = content.components(separatedBy: .newlines)
        var inComment = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip multi-line HTML comments
            if trimmed.contains("<!--") && trimmed.contains("-->") && !trimmed.hasPrefix("<!-- color:") {
                continue  // single-line comment (not a color directive)
            }
            if trimmed.contains("<!--") {
                inComment = true
                continue
            }
            if inComment {
                if trimmed.contains("-->") { inComment = false }
                continue
            }

            // H1 = category
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                // Save previous board
                if let board = currentBoard, let cat = currentCategory {
                    board.color = currentColor
                    switch cat {
                    case .features: featureBoards.append(board)
                    case .bugs: bugBoards.append(board)
                    }
                    currentBoard = nil
                    currentColor = .default
                }

                let categoryName = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if categoryName.lowercased() == "features" {
                    currentCategory = .features
                } else if categoryName.lowercased() == "bugs" {
                    currentCategory = .bugs
                }
                continue
            }

            // H2 = board name
            if trimmed.hasPrefix("## ") {
                // Save previous board
                if let board = currentBoard, let cat = currentCategory {
                    board.color = currentColor
                    switch cat {
                    case .features: featureBoards.append(board)
                    case .bugs: bugBoards.append(board)
                    }
                    currentColor = .default
                }

                let boardName = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentBoard = KanbanBoard(name: boardName)
                continue
            }

            // HTML comment for color
            if trimmed.hasPrefix("<!-- color:") && trimmed.hasSuffix("-->") {
                let colorStr = trimmed
                    .replacingOccurrences(of: "<!-- color:", with: "")
                    .replacingOccurrences(of: "-->", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let color = TerminalColor(rawValue: colorStr) {
                    currentColor = color
                }
                continue
            }

            // Checkbox bullets
            if trimmed.hasPrefix("- [") {
                let status: ItemStatus
                let textStart: String.Index

                if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                    status = .done
                    textStart = trimmed.index(trimmed.startIndex, offsetBy: 6)
                } else if trimmed.hasPrefix("- [/] ") {
                    status = .inProgress
                    textStart = trimmed.index(trimmed.startIndex, offsetBy: 6)
                } else if trimmed.hasPrefix("- [ ] ") {
                    status = .default
                    textStart = trimmed.index(trimmed.startIndex, offsetBy: 6)
                } else {
                    continue
                }

                let text = String(trimmed[textStart...])
                let bullet = Bullet(text: text, status: status)

                if currentBoard == nil {
                    // Create a default board if we see bullets before any ## header
                    let defaultName = currentCategory == .bugs ? "Bugs" : "Features"
                    currentBoard = KanbanBoard(name: defaultName)
                }
                currentBoard?.bullets.append(bullet)
                continue
            }
        }

        // Save last board
        if let board = currentBoard, let cat = currentCategory {
            board.color = currentColor
            switch cat {
            case .features: featureBoards.append(board)
            case .bugs: bugBoards.append(board)
            }
        }

        // Ensure at least one board per category
        if featureBoards.isEmpty { featureBoards = [KanbanBoard(name: "Features")] }
        if bugBoards.isEmpty { bugBoards = [KanbanBoard(name: "Bugs")] }

        return BacklogStore(featureBoards: featureBoards, bugBoards: bugBoards)
    }

    // MARK: - Serializer

    private func serialize(_ store: BacklogStore) -> String {
        var lines: [String] = []

        // Header
        lines.append("<!--")
        lines.append("  backlog.goat.md — Project backlog managed by GOAT Terminal (ClaudeTerm).")
        lines.append("")
        lines.append("  This file is auto-generated and kept in sync with the app's Backlog panel.")
        lines.append("  You can also edit it by hand — changes are picked up on the next load.")
        lines.append("")
        lines.append("  Format:")
        lines.append("    # Features / # Bugs   — top-level categories")
        lines.append("    ## Board Name          — a named board (tab) within the category")
        lines.append("    - [ ] item             — unstarted")
        lines.append("    - [/] item             — in progress")
        lines.append("    - [x] item             — completed")
        lines.append("    <!-- color: name -->    — optional board color (blue, green, red, etc.)")
        lines.append("")
        lines.append("  For AI agents: treat each unchecked item as a task prompt. Items under")
        lines.append("  \"# Features\" are feature requests; items under \"# Bugs\" are bug reports.")
        lines.append("  Mark items [/] when you start work and [x] when done.")
        lines.append("-->")
        lines.append("")

        // Features
        lines.append("# Features")
        lines.append("")
        for board in store.featureBoards {
            lines.append("## \(board.name)")
            if board.color != .default {
                lines.append("<!-- color: \(board.color.rawValue) -->")
            }
            for bullet in board.bullets where bullet.status != .deleted {
                let checkbox = checkboxString(for: bullet.status)
                lines.append("- [\(checkbox)] \(bullet.text)")
            }
            lines.append("")
        }

        // Bugs
        lines.append("# Bugs")
        lines.append("")
        for board in store.bugBoards {
            lines.append("## \(board.name)")
            if board.color != .default {
                lines.append("<!-- color: \(board.color.rawValue) -->")
            }
            for bullet in board.bullets where bullet.status != .deleted {
                let checkbox = checkboxString(for: bullet.status)
                lines.append("- [\(checkbox)] \(bullet.text)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func checkboxString(for status: ItemStatus) -> String {
        switch status {
        case .default: return " "
        case .inProgress: return "/"
        case .done: return "x"
        case .deleted: return "-"
        }
    }
}

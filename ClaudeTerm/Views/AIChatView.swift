import SwiftUI

struct AIChatView: View {
    @Bindable var chatSession: ChatSession
    let terminalSession: TerminalSession?
    let gitInfo: LocalGitInfo?
    let servers: [ServerSession]
    let backlogContext: String
    @State private var errorMessage: String?
    @State private var apiKeyInput: String = ""
    @State private var showApiKeyField = false
    @State private var hasApiKey: Bool = APIKeyManager.load() != nil

    var body: some View {
        VStack(spacing: 0) {
            // API Key setup prompt
            if !hasApiKey {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Claude API Key Required")
                        .font(PreferencesManager.uiFont(size: 14, weight: .semibold))
                    Text("Enter your Anthropic API key to start chatting.")
                        .font(PreferencesManager.uiFont(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if showApiKeyField {
                        VStack(spacing: 8) {
                            SecureField("sk-ant-...", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .font(PreferencesManager.uiFont(size: 12))
                                .frame(maxWidth: 300)

                            HStack(spacing: 8) {
                                Button("Cancel") {
                                    showApiKeyField = false
                                    apiKeyInput = ""
                                }
                                Button("Save") {
                                    let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
                                    if !key.isEmpty, APIKeyManager.save(key: key) {
                                        hasApiKey = true
                                        apiKeyInput = ""
                                        showApiKeyField = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    } else {
                        Button("Set Up API Key") {
                            showApiKeyField = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Messages
            else if chatSession.messages.isEmpty {
                Text("Chat with Claude")
                    .font(PreferencesManager.uiFont(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(chatSession.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: chatSession.messages.count) { _, _ in
                        if let last = chatSession.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }

            // Input area
            HStack(spacing: 8) {
                TextField("Message...", text: $chatSession.pendingInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(PreferencesManager.uiFont(size: 13))
                    .lineLimit(1...5)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: chatSession.isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(chatSession.pendingInput.trimmingCharacters(in: .whitespaces).isEmpty && !chatSession.isStreaming)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(6)
        }
    }

    private func buildSystemPrompt() -> String {
        var prompt = """
        You are the assistant in GOAT Terminal (Greatest of All Terminals). Your job is to help the user build their app — answer questions, debug issues, suggest approaches, and explain concepts clearly.

        Be friendly and encouraging. Explain things clearly and concisely.

        ## User's Environment

        Working directory: \(terminalSession?.currentDirectory ?? "unknown")
        """

        if let branch = terminalSession?.gitBranch {
            prompt += "\nGit branch: \(branch)"
        }

        // File tree
        if let dir = terminalSession?.currentDirectory {
            let tree = buildFileTree(at: dir, depth: 0, maxDepth: 3)
            if !tree.isEmpty {
                prompt += "\n\n## File Tree\n\n<file_tree>\n\(tree)\n</file_tree>"
            }
        }

        // Git status
        if let git = gitInfo {
            var section = "Branch: \(git.branch)"
            if let tracking = git.trackingBranch {
                section += " → \(tracking)"
                if git.ahead > 0 || git.behind > 0 {
                    section += " (ahead \(git.ahead), behind \(git.behind))"
                }
            }
            if git.stagedCount > 0 { section += "\nStaged: \(git.stagedCount) file(s)" }
            if git.modifiedCount > 0 { section += "\nModified: \(git.modifiedCount) file(s)" }
            if git.untrackedCount > 0 { section += "\nUntracked: \(git.untrackedCount) file(s)" }
            if git.conflictCount > 0 { section += "\nConflicts: \(git.conflictCount) file(s)" }
            if git.stashCount > 0 { section += "\nStashes: \(git.stashCount)" }
            if !git.recentCommits.isEmpty {
                section += "\nRecent commits:"
                for commit in git.recentCommits.prefix(5) {
                    section += "\n  \(commit.hash) \(commit.message)"
                }
            }
            prompt += "\n\n## Git Status\n\n<git_status>\n\(section)\n</git_status>"
        }

        // Include key project files from working directory
        if let dir = terminalSession?.currentDirectory {
            // README.md
            if let content = readFilePrefix(at: dir, name: "README.md", maxChars: 2000) {
                prompt += "\n\n## Project README\n\n<readme>\n\(content)\n</readme>"
            }

            // CLAUDE.md
            if let content = readFilePrefix(at: dir, name: "CLAUDE.md", maxChars: 2000) {
                prompt += "\n\n## CLAUDE.md\n\n<claude_md>\n\(content)\n</claude_md>"
            }

            // Manifest files (first match wins)
            let manifests = ["Package.swift", "package.json", "Cargo.toml", "pyproject.toml",
                             "Gemfile", "go.mod", "pom.xml", "build.gradle", "composer.json"]
            for manifest in manifests {
                if let content = readFilePrefix(at: dir, name: manifest, maxChars: 3000) {
                    prompt += "\n\n## Project Manifest (\(manifest))\n\n<manifest>\n\(content)\n</manifest>"
                    break
                }
            }

            // .env variable names only (no values)
            let envNames = [".env", ".env.local", ".env.development"]
            for envName in envNames {
                let envPath = (dir as NSString).appendingPathComponent(envName)
                if let data = FileManager.default.contents(atPath: envPath),
                   let raw = String(data: data, encoding: .utf8) {
                    let keys = raw.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && !$0.hasPrefix("#") && $0.contains("=") }
                        .compactMap { $0.components(separatedBy: "=").first?.trimmingCharacters(in: .whitespaces) }
                    if !keys.isEmpty {
                        prompt += "\n\n## Environment Variables (\(envName))\n\nVariable names only (values are hidden for security):\n\n<env_keys>\n\(keys.joined(separator: "\n"))\n</env_keys>"
                    }
                    break
                }
            }
        }

        // Servers
        if !servers.isEmpty {
            var section = ""
            for server in servers {
                var line = "- \(server.name): \(server.status.rawValue)"
                if let port = server.detectedPort {
                    line += " (port \(port))"
                }
                line += " — `\(server.command)`"
                section += section.isEmpty ? line : "\n\(line)"
            }
            prompt += "\n\n## Dev Servers\n\n<servers>\n\(section)\n</servers>"
        }

        // Include backlog if non-empty
        if !backlogContext.isEmpty {
            prompt += "\n\n## Backlog\n\n<backlog>\n\(backlogContext)\n</backlog>"
        }

        return prompt
    }

    private func readFilePrefix(at dir: String, name: String, maxChars: Int) -> String? {
        let path = (dir as NSString).appendingPathComponent(name)
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8),
              !content.isEmpty else { return nil }
        return String(content.prefix(maxChars))
    }

    private static let ignoredDirectories: Set<String> = [
        ".git", "node_modules", ".build", ".swiftpm", "DerivedData",
        "Pods", ".cocoapods", "vendor", "dist", "build", ".next",
        "__pycache__", ".venv", "venv", ".tox", ".cache"
    ]

    private func buildFileTree(at path: String, depth: Int, maxDepth: Int) -> String {
        guard depth <= maxDepth else { return "" }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return "" }

        let indent = String(repeating: "  ", count: depth)
        var lines: [String] = []

        let sorted = entries.filter { !$0.hasPrefix(".") || $0 == ".env" }
            .sorted { a, b in
                var aDirFlag: ObjCBool = false
                var bDirFlag: ObjCBool = false
                fm.fileExists(atPath: (path as NSString).appendingPathComponent(a), isDirectory: &aDirFlag)
                fm.fileExists(atPath: (path as NSString).appendingPathComponent(b), isDirectory: &bDirFlag)
                if aDirFlag.boolValue != bDirFlag.boolValue { return aDirFlag.boolValue }
                return a.localizedStandardCompare(b) == .orderedAscending
            }

        for entry in sorted {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)

            if isDir.boolValue {
                if Self.ignoredDirectories.contains(entry) { continue }
                lines.append("\(indent)\(entry)/")
                let subtree = buildFileTree(at: fullPath, depth: depth + 1, maxDepth: maxDepth)
                if !subtree.isEmpty { lines.append(subtree) }
            } else {
                lines.append("\(indent)\(entry)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func sendMessage() {
        let text = chatSession.pendingInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        chatSession.addMessage(role: .user, content: text)
        chatSession.pendingInput = ""
        errorMessage = nil

        let messages = chatSession.messages.map { (role: $0.role.rawValue, content: $0.content) }
        let systemPrompt = buildSystemPrompt()

        chatSession.isStreaming = true
        chatSession.addMessage(role: .assistant, content: "")

        Task {
            do {
                try await ClaudeAPIService.shared.sendMessage(
                    messages: messages,
                    systemPrompt: systemPrompt
                ) { token in
                    DispatchQueue.main.async {
                        chatSession.messages.last?.content += token
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    if chatSession.messages.last?.content.isEmpty == true {
                        chatSession.messages.removeLast()
                    }
                }
            }
            await MainActor.run {
                chatSession.isStreaming = false
            }
        }
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content.isEmpty ? "..." : message.content)
                .font(PreferencesManager.uiFont(size: 13))
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

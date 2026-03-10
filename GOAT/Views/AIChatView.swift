import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Overlay Scroller

private struct OverlayScrollerStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                scrollView.scrollerStyle = .overlay
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct AIChatView: View {
    @Bindable var chatSession: ChatSession
    let terminalSession: TerminalSession?
    let gitInfo: LocalGitInfo?
    let serverStore: ServerStore
    let currentDirectory: String
    let backlogContextProvider: () -> String
    var onServerStarted: (() -> Void)?
    @State private var errorMessage: String?
    @State private var apiKeyInput: String = ""
    @State private var showApiKeyField = false
    @State private var hasApiKey: Bool = APIKeyManager.load() != nil
    @State private var pendingAttachments: [ChatAttachment] = []
    @State private var isDropTargeted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area — fills the full height
            if !hasApiKey {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 0) {
                        Text("Enter your ")
                            .font(PreferencesManager.uiFont(size: 12))
                            .foregroundColor(.secondary)
                        Text("Anthropic API Key")
                            .font(PreferencesManager.uiFont(size: 12))
                            .foregroundColor(.accentColor)
                            .underline()
                            .onTapGesture {
                                if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        Text(" to start chatting.")
                            .font(PreferencesManager.uiFont(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if showApiKeyField {
                        HStack(spacing: 8) {
                            SecureField("sk-ant-...", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .font(PreferencesManager.uiFont(size: 12))
                                .onSubmit {
                                    let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
                                    if !key.isEmpty, APIKeyManager.save(key: key) {
                                        hasApiKey = true
                                        apiKeyInput = ""
                                        showApiKeyField = false
                                    }
                                }
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
                    } else {
                        Button("Set Up API Key") {
                            showApiKeyField = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
                .padding(.top, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ZStack(alignment: .bottom) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            if chatSession.messages.isEmpty {
                                HStack(spacing: 0) {
                                    Text("Chat with Claude. See ")
                                        .font(PreferencesManager.uiFont(size: 12))
                                        .foregroundColor(.secondary)
                                    Text("current context")
                                        .font(PreferencesManager.uiFont(size: 12))
                                        .foregroundColor(.accentColor)
                                        .underline()
                                        .onTapGesture { requestContextSummary() }
                                    Text(".")
                                        .font(PreferencesManager.uiFont(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .padding(.top, 34)
                            } else {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(chatSession.messages) { message in
                                        ChatBubbleView(message: message)
                                            .id(message.id)
                                    }
                                }
                                .padding(8)
                                .padding(.top, 34)
                                .padding(.bottom, 56)
                            }
                        }
                        .background(OverlayScrollerStyle())
                        .mask(
                            VStack(spacing: 0) {
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black, location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 46)

                                Color.black
                            }
                        )
                        .onChange(of: chatSession.messages.count) { _, _ in
                            if let last = chatSession.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }

                    if hasApiKey {
                        floatingInputBar
                    }
                }
            }
        }
        .overlay(
            ZStack {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundColor(Color.accentColor.opacity(0.5))
                }
            }
        )
        .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers)
        }
    }

    // MARK: - Floating Input Bar

    @ViewBuilder
    private var floatingInputBar: some View {
        VStack(spacing: 0) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }

            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pendingAttachments) { attachment in
                            ZStack(alignment: .topTrailing) {
                                if attachment.isPDF {
                                    VStack(spacing: 2) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.red)
                                        Text(attachment.fileName ?? "PDF")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 60, height: 60)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)))
                                } else if attachment.isImage, let nsImage = NSImage(data: attachment.data) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else if attachment.isTextFile {
                                    VStack(spacing: 2) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.accentColor)
                                        Text(attachment.fileName ?? "File")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 60, height: 60)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)))
                                }

                                Button(action: { removePendingAttachment(attachment.id) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .background(Circle().fill(Color(nsColor: .controlBackgroundColor)).frame(width: 14, height: 14))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }
            }

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
                .disabled(chatSession.pendingInput.trimmingCharacters(in: .whitespaces).isEmpty && pendingAttachments.isEmpty && !chatSession.isStreaming)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.leading, 6)
            .padding(.trailing, 18)
            .padding(.vertical, 6)
        }
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.5), location: 0.4),
                    .init(color: .white.opacity(0.75), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.softLight)
            .padding(.trailing, 18)
        )
    }

    private func buildSystemPrompt() -> String {
        let ctx = PreferencesManager.shared

        let toneInstruction: String
        switch ctx.chatTone {
        case "detailed":
            toneInstruction = "Be thorough and helpful. Provide detailed explanations, examples, and context. Walk the user through your reasoning step by step."
        case "concise":
            toneInstruction = "Be brief and direct. Give short, to-the-point answers. Skip pleasantries and filler — lead with the answer or action."
        default:
            toneInstruction = "Be friendly and encouraging. Explain things clearly and concisely."
        }

        var prompt = """
        You are the assistant in GOAT (Greatest of All Terminals). Your job is to help the user build their app — answer questions, debug issues, suggest approaches, and explain concepts clearly.

        \(toneInstruction)

        ## User's Environment

        Working directory: \(terminalSession?.currentDirectory ?? "unknown")
        """

        if let branch = terminalSession?.gitBranch {
            prompt += "\nGit branch: \(branch)"
        }

        // File tree
        if ctx.contextFileTree, let dir = terminalSession?.currentDirectory {
            let tree = buildFileTree(at: dir, depth: 0, maxDepth: 3)
            if !tree.isEmpty {
                prompt += "\n\n## File Tree\n\n<file_tree>\n\(tree)\n</file_tree>"
            }
        }

        // Git status
        if ctx.contextGitStatus, let git = gitInfo {
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
            if ctx.contextReadme, let content = readFilePrefix(at: dir, name: "README.md", maxChars: 2000) {
                prompt += "\n\n## Project README\n\n<readme>\n\(content)\n</readme>"
            }

            // CLAUDE.md
            if ctx.contextClaudeMd, let content = readFilePrefix(at: dir, name: "CLAUDE.md", maxChars: 2000) {
                prompt += "\n\n## CLAUDE.md\n\n<claude_md>\n\(content)\n</claude_md>"
            }

            // Manifest files (first match wins)
            if ctx.contextManifest {
                let manifests = ["Package.swift", "package.json", "Cargo.toml", "pyproject.toml",
                                 "Gemfile", "go.mod", "pom.xml", "build.gradle", "composer.json"]
                for manifest in manifests {
                    if let content = readFilePrefix(at: dir, name: manifest, maxChars: 3000) {
                        prompt += "\n\n## Project Manifest (\(manifest))\n\n<manifest>\n\(content)\n</manifest>"
                        break
                    }
                }
            }

            // .env variable names only (no values)
            if ctx.contextEnvVars {
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
        }

        // Servers
        if ctx.contextServers, !serverStore.servers.isEmpty {
            var section = ""
            for server in serverStore.servers {
                var line = "- \(server.name): \(server.status.rawValue)"
                if let port = server.detectedPort {
                    line += " (port \(port))"
                }
                line += " — `\(server.command)`"
                section += section.isEmpty ? line : "\n\(line)"
            }
            prompt += "\n\n## Dev Servers\n\n<servers>\n\(section)\n</servers>"
        }

        // Actions
        prompt += """


        ## Actions

        You can start dev servers in GOAT's Servers panel. When the user asks you to start a server, include a goat-action fenced code block in your response:

        ```goat-action
        {"action":"start_server","name":"Frontend","command":"npm run dev"}
        ```

        Rules:
        - Only use `start_server` when the user explicitly asks to start/run a server.
        - `name` should be a short label (e.g. "Frontend", "API Server").
        - `command` should be the exact shell command to run.
        - You may include multiple action blocks if the user asks for multiple servers.
        - Always include a brief human-readable explanation alongside the action block.
        """

        // Include backlog if non-empty
        let backlogText = backlogContextProvider()
        if ctx.contextBacklog, !backlogText.isEmpty {
            prompt += "\n\n## Backlog\n\n<backlog>\n\(backlogText)\n</backlog>"
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

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                handled = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, _ in
                    guard let data else { return }
                    DispatchQueue.main.async {
                        self.pendingAttachments.append(
                            ChatAttachment(data: data, mediaType: "application/pdf", fileName: nil, fileText: nil)
                        )
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    DispatchQueue.main.async {
                        self.pendingAttachments.append(
                            ChatAttachment(data: data, mediaType: "image/png", fileName: nil, fileText: nil)
                        )
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let urlItem = item as? URL {
                        url = urlItem
                    } else if let data = item as? Data,
                              let urlString = String(data: data, encoding: .utf8) {
                        url = URL(string: urlString)
                    } else {
                        url = nil
                    }
                    guard let url = url else { return }
                    let fileName = url.lastPathComponent
                    if let text = try? String(contentsOf: url, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.pendingAttachments.append(
                                ChatAttachment(data: Data(), mediaType: "text/plain", fileName: fileName, fileText: text)
                            )
                        }
                    }
                }
            }
        }
        return handled
    }

    private func clearPendingFile() {
        pendingAttachments.removeAll()
    }

    private func removePendingAttachment(_ id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    private func requestContextSummary() {
        chatSession.addMessage(role: .user, content: "What context do you have about my project?")
        errorMessage = nil

        let messages = chatSession.messages.map { (role: $0.role.rawValue, content: $0.content, attachments: $0.attachments) }
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

    private func sendMessage() {
        let text = chatSession.pendingInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        // Build message text, incorporating any text file attachments inline
        let textAttachments = pendingAttachments.filter { $0.isTextFile }
        let mediaAttachments = pendingAttachments.filter { !$0.isTextFile }

        var msgText: String
        if !textAttachments.isEmpty {
            let userText = text.isEmpty ? "Here is the file content. Please review it." : text
            var parts = [userText]
            for attachment in textAttachments {
                let name = attachment.fileName ?? "file"
                parts.append("\n**\(name)**:\n```\n\(attachment.fileText ?? "")\n```")
            }
            msgText = parts.joined()
        } else if text.isEmpty {
            msgText = !mediaAttachments.isEmpty ? "What's in this?" : text
        } else {
            msgText = text
        }

        let msg = ChatMessage(role: .user, content: msgText, attachments: mediaAttachments)
        chatSession.messages.append(msg)
        chatSession.pendingInput = ""
        clearPendingFile()
        errorMessage = nil

        let messages = chatSession.messages.map { (role: $0.role.rawValue, content: $0.content, attachments: $0.attachments) }
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
                processActions()
            }
        }
    }

    private func processActions() {
        guard let lastMessage = chatSession.messages.last,
              lastMessage.role == .assistant else { return }

        let actions = GoatActionParser.parse(from: lastMessage.content)
        guard !actions.isEmpty else { return }

        // Strip action blocks from displayed content
        lastMessage.content = GoatActionParser.stripActionBlocks(from: lastMessage.content)

        var didStartServer = false
        for action in actions where action.action == "start_server" {
            guard let command = action.command, !command.isEmpty else { continue }
            let name = action.name ?? command
            let server = serverStore.addServer(name: name, command: command)

            // Only start if not already running
            if server.status == ServerStatus.stopped || server.status == ServerStatus.error {
                DevServerService.shared.start(server: server, directory: currentDirectory)
                didStartServer = true
            }
        }

        if didStartServer {
            onServerStarted?()
        }
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme

    private var bubbleColor: Color {
        if message.role == .user {
            return .blue
        } else {
            return colorScheme == .dark
                ? Color(nsColor: .darkGray)
                : Color(white: 0.9)
        }
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user { Spacer(minLength: 40) }

            if message.role == .assistant {
                // Tail on left for assistant
                BubbleTail(isFromUser: false)
                    .fill(bubbleColor)
                    .frame(width: 10, height: 16)
                    .offset(x: 6, y: 0)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if !message.attachments.isEmpty {
                    let cols = min(message.attachments.count, 3)
                    let gridItems = Array(repeating: GridItem(.flexible(), spacing: 4), count: cols)
                    LazyVGrid(columns: gridItems, spacing: 4) {
                        ForEach(message.attachments) { attachment in
                            if attachment.isPDF {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    Text("PDF")
                                        .font(PreferencesManager.uiFont(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)))
                            } else if attachment.isImage, let nsImage = NSImage(data: attachment.data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 200, maxHeight: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                if !message.content.isEmpty {
                    Text(message.content)
                        .font(PreferencesManager.uiFont(size: 13))
                        .foregroundColor(textColor)
                        .textSelection(.enabled)
                } else if message.attachments.isEmpty {
                    Text("...")
                        .font(PreferencesManager.uiFont(size: 13))
                        .foregroundColor(textColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16))

            if message.role == .user {
                // Tail on right for user
                BubbleTail(isFromUser: true)
                    .fill(bubbleColor)
                    .frame(width: 10, height: 16)
                    .offset(x: -6, y: 0)
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Bubble Tail Shape

struct BubbleTail: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isFromUser {
            // Tail curves out to bottom-right
            path.move(to: CGPoint(x: 0, y: rect.maxY - 4))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: 0, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.minY),
                control: CGPoint(x: rect.maxX * 0.1, y: rect.maxY * 0.5)
            )
        } else {
            // Tail curves out to bottom-left
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.maxX * 0.9, y: rect.maxY * 0.5)
            )
        }
        path.closeSubpath()
        return path
    }
}

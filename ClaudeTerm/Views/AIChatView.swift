import SwiftUI

struct AIChatView: View {
    @Bindable var chatSession: ChatSession
    let backlogContext: String

    @State private var includeBacklog = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            if chatSession.messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Chat with Claude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            Divider()

            // Input area
            HStack(spacing: 8) {
                Button(action: { includeBacklog.toggle() }) {
                    Image(systemName: includeBacklog ? "doc.fill" : "doc")
                        .font(.system(size: 12))
                        .foregroundColor(includeBacklog ? .accentColor : .secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .help(includeBacklog ? "Backlog context included" : "Include backlog as context")

                TextField("Ask Claude...", text: $chatSession.pendingInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
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
            .padding(8)
        }
    }

    private func sendMessage() {
        let text = chatSession.pendingInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        chatSession.addMessage(role: .user, content: text)
        chatSession.pendingInput = ""
        errorMessage = nil

        let messages = chatSession.messages.map { (role: $0.role.rawValue, content: $0.content) }
        let systemPrompt = includeBacklog && !backlogContext.isEmpty ? "Context from user's backlog:\n\(backlogContext)" : nil

        chatSession.isStreaming = true
        chatSession.addMessage(role: .assistant, content: "")

        Task {
            do {
                try await ClaudeAPIService.shared.sendMessage(
                    messages: messages.dropLast().map { $0 },
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
                .font(.system(size: 13))
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

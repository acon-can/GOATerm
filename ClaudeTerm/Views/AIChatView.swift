import SwiftUI

struct AIChatView: View {
    @Bindable var chatSession: ChatSession
    let backlogContext: String

    @State private var includeBacklog = false
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

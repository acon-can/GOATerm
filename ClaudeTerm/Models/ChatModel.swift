import Foundation

enum ChatRole: String {
    case user
    case assistant
}

@Observable
final class ChatMessage: Identifiable {
    let id: UUID
    let role: ChatRole
    var content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

@Observable
final class ChatSession {
    var messages: [ChatMessage] = []
    var isStreaming: Bool = false
    var pendingInput: String = ""

    func addMessage(role: ChatRole, content: String) {
        messages.append(ChatMessage(role: role, content: content))
    }

    func clear() {
        messages.removeAll()
        isStreaming = false
        pendingInput = ""
    }
}

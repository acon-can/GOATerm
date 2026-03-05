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
    var imageData: Data?
    var imageMediaType: String?

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date(), imageData: Data? = nil, imageMediaType: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.imageData = imageData
        self.imageMediaType = imageMediaType
    }
}

struct GoatAction: Codable {
    let action: String
    let name: String?
    let command: String?
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

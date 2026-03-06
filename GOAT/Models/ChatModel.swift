import Foundation

enum ChatRole: String {
    case user
    case assistant
}

struct ChatAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let mediaType: String
    let fileName: String?
    let fileText: String?

    var isImage: Bool { mediaType.hasPrefix("image/") }
    var isPDF: Bool { mediaType == "application/pdf" }
    var isTextFile: Bool { fileText != nil }
}

@Observable
final class ChatMessage: Identifiable {
    let id: UUID
    let role: ChatRole
    var content: String
    let timestamp: Date
    var attachments: [ChatAttachment]

    // Legacy single-image accessors for API compatibility
    var imageData: Data? { attachments.first(where: { !$0.isTextFile })?.data }
    var imageMediaType: String? { attachments.first(where: { !$0.isTextFile })?.mediaType }

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date(), imageData: Data? = nil, imageMediaType: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        if let data = imageData, let type = imageMediaType {
            self.attachments = [ChatAttachment(data: data, mediaType: type, fileName: nil, fileText: nil)]
        } else {
            self.attachments = []
        }
    }

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date(), attachments: [ChatAttachment] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachments = attachments
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

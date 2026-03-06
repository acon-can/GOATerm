import Foundation

enum SplitOrientation: String, Codable {
    case horizontal
    case vertical
}

indirect enum PaneNode: Identifiable {
    case terminal(TerminalSession)
    case split(orientation: SplitOrientation, first: PaneNode, second: PaneNode, ratio: Double)

    var id: String {
        switch self {
        case .terminal(let session):
            return session.id.uuidString
        case .split(_, let first, let second, _):
            return "split-\(first.id)-\(second.id)"
        }
    }

    var allSessions: [TerminalSession] {
        switch self {
        case .terminal(let session):
            return [session]
        case .split(_, let first, let second, _):
            return first.allSessions + second.allSessions
        }
    }

    var firstSession: TerminalSession? {
        switch self {
        case .terminal(let session):
            return session
        case .split(_, let first, _, _):
            return first.firstSession
        }
    }

    func contains(sessionId: UUID) -> Bool {
        switch self {
        case .terminal(let session):
            return session.id == sessionId
        case .split(_, let first, let second, _):
            return first.contains(sessionId: sessionId) || second.contains(sessionId: sessionId)
        }
    }

    func replacing(sessionId: UUID, with newNode: PaneNode) -> PaneNode {
        switch self {
        case .terminal(let session):
            if session.id == sessionId {
                return newNode
            }
            return self
        case .split(let orientation, let first, let second, let ratio):
            return .split(
                orientation: orientation,
                first: first.replacing(sessionId: sessionId, with: newNode),
                second: second.replacing(sessionId: sessionId, with: newNode),
                ratio: ratio
            )
        }
    }

    func removing(sessionId: UUID) -> PaneNode? {
        switch self {
        case .terminal(let session):
            if session.id == sessionId {
                return nil
            }
            return self
        case .split(let orientation, let first, let second, let ratio):
            let newFirst = first.removing(sessionId: sessionId)
            let newSecond = second.removing(sessionId: sessionId)
            if let f = newFirst, let s = newSecond {
                return .split(orientation: orientation, first: f, second: s, ratio: ratio)
            }
            return newFirst ?? newSecond
        }
    }
}

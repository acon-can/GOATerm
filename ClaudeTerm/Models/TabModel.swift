import Foundation

@Observable
final class TabModel: Identifiable {
    let id: UUID
    var rootPane: PaneNode
    var focusedSessionId: UUID?

    init(id: UUID = UUID(), session: TerminalSession? = nil) {
        self.id = id
        let sess = session ?? TerminalSession()
        self.rootPane = .terminal(sess)
        self.focusedSessionId = sess.id
    }

    var allSessions: [TerminalSession] {
        rootPane.allSessions
    }

    var focusedSession: TerminalSession? {
        if let focusedId = focusedSessionId {
            return allSessions.first { $0.id == focusedId }
        }
        return rootPane.firstSession
    }

    var displayTitle: String {
        focusedSession?.shortTitle ?? "Terminal"
    }

    var color: TerminalColor {
        focusedSession?.color ?? .default
    }

    func splitPane(sessionId: UUID, orientation: SplitOrientation) {
        let newSession = TerminalSession()
        if let existingSession = allSessions.first(where: { $0.id == sessionId }) {
            newSession.currentDirectory = existingSession.currentDirectory
        }
        let newNode = PaneNode.split(
            orientation: orientation,
            first: .terminal(allSessions.first { $0.id == sessionId }!),
            second: .terminal(newSession),
            ratio: 0.5
        )
        rootPane = rootPane.replacing(sessionId: sessionId, with: newNode)
        focusedSessionId = newSession.id
    }

    func closePane(sessionId: UUID) -> Bool {
        if case .terminal = rootPane {
            return false // Can't close the last pane
        }
        if let newRoot = rootPane.removing(sessionId: sessionId) {
            rootPane = newRoot
            if focusedSessionId == sessionId {
                focusedSessionId = rootPane.firstSession?.id
            }
            return true
        }
        return false
    }

    func nextSession(after currentId: UUID) -> TerminalSession? {
        let sessions = allSessions
        guard let idx = sessions.firstIndex(where: { $0.id == currentId }) else { return nil }
        let nextIdx = (idx + 1) % sessions.count
        return sessions[nextIdx]
    }

    func previousSession(before currentId: UUID) -> TerminalSession? {
        let sessions = allSessions
        guard let idx = sessions.firstIndex(where: { $0.id == currentId }) else { return nil }
        let prevIdx = (idx - 1 + sessions.count) % sessions.count
        return sessions[prevIdx]
    }
}

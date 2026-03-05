import Foundation
import AppKit

@Observable
final class EnvironmentEditorState {
    var selectedFile: String?
    var editorContent: String = ""
    var originalContent: String = ""
    var isDirty: Bool = false

    func selectFile(_ path: String) {
        selectedFile = path
        if let data = FileManager.default.contents(atPath: path),
           let content = String(data: data, encoding: .utf8) {
            editorContent = content
            originalContent = content
        } else {
            editorContent = ""
            originalContent = ""
        }
        isDirty = false
    }

    func save(serverStore: ServerStore, currentDirectory: String, onSwitchToServers: @escaping () -> Void) {
        guard let path = selectedFile else { return }
        do {
            try editorContent.write(toFile: path, atomically: true, encoding: .utf8)
            originalContent = editorContent
            isDirty = false
            promptServerRestart(serverStore: serverStore, currentDirectory: currentDirectory, onSwitchToServers: onSwitchToServers)
        } catch {}
    }

    func discard() {
        if let path = selectedFile {
            selectFile(path)
        }
    }

    func updateDirty() {
        isDirty = editorContent != originalContent
    }

    private func promptServerRestart(serverStore: ServerStore, currentDirectory: String, onSwitchToServers: @escaping () -> Void) {
        let runningServers = serverStore.servers.filter { $0.status == .running || $0.status == .starting }
        guard !runningServers.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Environment file changed"
        alert.informativeText = "Restart running servers to apply changes?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            for server in runningServers {
                DevServerService.shared.restart(server: server, directory: currentDirectory)
            }
            if let first = runningServers.first {
                serverStore.selectedServerId = first.id
            }
            onSwitchToServers()
        }
    }
}

@Observable
final class TabModel: Identifiable {
    let id: UUID
    var rootPane: PaneNode
    var focusedSessionId: UUID?
    var chatSession: ChatSession = ChatSession()
    var editorState: EditorState = EditorState()
    var serverStore: ServerStore = ServerStore()
    var envEditorState: EnvironmentEditorState = EnvironmentEditorState()
    var settingsEditorState: EnvironmentEditorState = EnvironmentEditorState()

    init(id: UUID = UUID(), session: TerminalSession? = nil) {
        self.id = id
        let sess = session ?? TerminalSession()
        self.rootPane = .terminal(sess)
        self.focusedSessionId = sess.id
        self.editorState.rootDirectory = sess.currentDirectory
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
        let newSession = TerminalSession(color: .nextRotatingColor())
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

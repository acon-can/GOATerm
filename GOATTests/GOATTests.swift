import XCTest
@testable import GOAT

final class GOATTests: XCTestCase {
    func testTerminalSessionDefaults() {
        let session = TerminalSession()
        XCTAssertEqual(session.name, "Terminal")
        XCTAssertEqual(session.color, .default)
        XCTAssertTrue(session.isRunning)
        XCTAssertNil(session.gitBranch)
        XCTAssertNil(session.runningCommand)
    }

    func testTerminalSessionDisplayTitle() {
        let session = TerminalSession(name: "API Server", currentDirectory: "/Users/test/project")
        session.gitBranch = "main"
        XCTAssertEqual(session.displayTitle, "API Server | ~/project | git:main")

        session.runningCommand = "npm dev"
        XCTAssertEqual(session.displayTitle, "API Server | ~/project | git:main | npm dev")
    }

    func testTabModelOperations() {
        let tab = TabModel()
        XCTAssertEqual(tab.allSessions.count, 1)

        let sessionId = tab.allSessions[0].id
        tab.splitPane(sessionId: sessionId, orientation: .horizontal)
        XCTAssertEqual(tab.allSessions.count, 2)

        // Close a pane
        let newSessionId = tab.allSessions[1].id
        let closed = tab.closePane(sessionId: newSessionId)
        XCTAssertTrue(closed)
        XCTAssertEqual(tab.allSessions.count, 1)
    }

    func testWindowStateTabManagement() {
        let state = WindowState()
        XCTAssertEqual(state.tabs.count, 1)

        state.addTab()
        XCTAssertEqual(state.tabs.count, 2)

        state.addTab()
        XCTAssertEqual(state.tabs.count, 3)

        // Switch tabs
        state.switchToTab(at: 0)
        XCTAssertEqual(state.activeTabId, state.tabs[0].id)

        // Close active
        state.closeActiveTab()
        XCTAssertEqual(state.tabs.count, 2)
    }

    func testPaneNodeOperations() {
        let session1 = TerminalSession()
        let session2 = TerminalSession()
        let node = PaneNode.split(
            orientation: .horizontal,
            first: .terminal(session1),
            second: .terminal(session2),
            ratio: 0.5
        )

        XCTAssertEqual(node.allSessions.count, 2)
        XCTAssertTrue(node.contains(sessionId: session1.id))
        XCTAssertTrue(node.contains(sessionId: session2.id))

        // Remove one
        let reduced = node.removing(sessionId: session1.id)
        XCTAssertEqual(reduced?.allSessions.count, 1)
    }

    func testWorkspaceLayout() {
        let state = WindowState()
        state.tabs[0].focusedSession?.name = "Dev Server"
        state.tabs[0].focusedSession?.color = .green
        state.addTab()
        state.tabs[1].focusedSession?.name = "Tests"

        let layout = WorkspaceLayout.capture(from: state, name: "My Project")
        XCTAssertEqual(layout.name, "My Project")
        XCTAssertEqual(layout.tabs.count, 2)

        let restoredTabs = layout.restore()
        XCTAssertEqual(restoredTabs.count, 2)
    }

    func testPTYManager() {
        let shell = PTYManager.defaultShell
        XCTAssertFalse(shell.isEmpty)

        XCTAssertEqual(PTYManager.shellName(from: "/bin/zsh"), "zsh")
        XCTAssertEqual(PTYManager.shellName(from: "/usr/local/bin/fish"), "fish")

        let validDir = PTYManager.validatedWorkingDirectory(NSHomeDirectory())
        XCTAssertEqual(validDir, NSHomeDirectory())

        let invalidDir = PTYManager.validatedWorkingDirectory("/nonexistent/path")
        XCTAssertEqual(invalidDir, NSHomeDirectory())
    }
}

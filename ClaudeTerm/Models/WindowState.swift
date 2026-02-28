import Foundation

@Observable
final class WindowState {
    var tabs: [TabModel] = []
    var activeTabId: UUID?
    var showSaveWorkspace: Bool = false
    var showWorkspaceManager: Bool = false
    var backlog: BacklogStore = BacklogStore()
    var isBacklogVisible: Bool = true
    var backlogWidthRatio: Double = 0.25
    var showClaudeProject: Bool = false
    var editorState: EditorState = EditorState()
    var agentStore: AgentStore = AgentStore()
    var githubState: GitHubState = GitHubState()

    init() {
        let firstTab = TabModel()
        tabs = [firstTab]
        activeTabId = firstTab.id
    }

    var activeTab: TabModel? {
        tabs.first { $0.id == activeTabId }
    }

    var activeTabIndex: Int? {
        tabs.firstIndex { $0.id == activeTabId }
    }

    // MARK: - Tab Operations

    func addTab(session: TerminalSession? = nil) {
        let tab = TabModel(session: session)
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)
            if activeTabId == id {
                let newIndex = min(index, tabs.count - 1)
                activeTabId = tabs[newIndex].id
            }
        }
    }

    func closeActiveTab() {
        guard let id = activeTabId else { return }
        closeTab(id: id)
    }

    func closeOtherTabs(keepingId: UUID) {
        tabs.removeAll { $0.id != keepingId }
        activeTabId = keepingId
    }

    func switchToTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTabId = tabs[index].id
    }

    func selectPreviousTab() {
        guard let currentIndex = activeTabIndex else { return }
        let newIndex = (currentIndex - 1 + tabs.count) % tabs.count
        activeTabId = tabs[newIndex].id
    }

    func selectNextTab() {
        guard let currentIndex = activeTabIndex else { return }
        let newIndex = (currentIndex + 1) % tabs.count
        activeTabId = tabs[newIndex].id
    }

    func moveTab(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < tabs.count,
              toIndex >= 0, toIndex < tabs.count else { return }
        let tab = tabs.remove(at: fromIndex)
        tabs.insert(tab, at: toIndex)
    }

    func duplicateTab(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }),
              let session = tab.focusedSession else { return }
        let newSession = TerminalSession(
            name: session.name,
            color: session.color,
            currentDirectory: session.currentDirectory
        )
        addTab(session: newSession)
    }

    // MARK: - Backlog

    func toggleBacklog() {
        isBacklogVisible.toggle()
    }

    // MARK: - Pane Operations

    func splitActivePane(orientation: SplitOrientation) {
        guard let tab = activeTab,
              let sessionId = tab.focusedSessionId else { return }
        tab.splitPane(sessionId: sessionId, orientation: orientation)
    }

    func closeActivePane() {
        guard let tab = activeTab,
              let sessionId = tab.focusedSessionId else { return }
        if !tab.closePane(sessionId: sessionId) {
            // Last pane in tab - close the tab
            closeActiveTab()
        }
    }

    func focusNextPane() {
        guard let tab = activeTab,
              let currentId = tab.focusedSessionId,
              let next = tab.nextSession(after: currentId) else { return }
        tab.focusedSessionId = next.id
    }

    func focusPreviousPane() {
        guard let tab = activeTab,
              let currentId = tab.focusedSessionId,
              let prev = tab.previousSession(before: currentId) else { return }
        tab.focusedSessionId = prev.id
    }
}

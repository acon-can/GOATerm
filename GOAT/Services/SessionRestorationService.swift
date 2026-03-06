import Foundation

final class SessionRestorationService {
    static let shared = SessionRestorationService()

    private let stateFile: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("GOAT")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        stateFile = dir.appendingPathComponent("session-state.json")
    }

    struct SavedState: Codable {
        var tabs: [SavedTab]
        var activeTabIndex: Int
        var backlog: BacklogLayout?  // kept for backward compat reading

        struct SavedTab: Codable {
            var rootPane: PaneLayout
            var focusedSessionName: String?
            var agents: [WorkspaceLayout.ServerLayout]?  // legacy field name kept for backward compat
        }
    }

    func saveState(from windowState: WindowState) {
        // Save all cached backlogs to their directories
        windowState.saveActiveBacklog()

        let savedTabs = windowState.tabs.map { tab in
            // Servers are discovered from README — don't persist configs
            return SavedState.SavedTab(
                rootPane: PaneLayout.fromPaneNode(tab.rootPane),
                focusedSessionName: tab.focusedSession?.name,
                agents: nil
            )
        }

        let activeIndex = windowState.activeTabIndex ?? 0
        let state = SavedState(tabs: savedTabs, activeTabIndex: activeIndex, backlog: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(state)
            try data.write(to: stateFile)
        } catch {
            print("Failed to save session state: \(error)")
        }
    }

    func restoreState(into windowState: WindowState) -> Bool {
        let decoder = JSONDecoder()

        guard let data = try? Data(contentsOf: stateFile),
              let state = try? decoder.decode(SavedState.self, from: data),
              !state.tabs.isEmpty else {
            return false
        }

        let tabs = state.tabs.map { savedTab in
            let rootNode = savedTab.rootPane.toPaneNode()
            let tab = TabModel()
            tab.rootPane = rootNode
            tab.focusedSessionId = rootNode.firstSession?.id
            if let dir = rootNode.firstSession?.currentDirectory {
                tab.editorState.rootDirectory = dir
            }
            // Legacy agent configs are ignored — servers re-discovered from README
            return tab
        }

        windowState.tabs = tabs
        let activeIndex = min(state.activeTabIndex, tabs.count - 1)
        windowState.activeTabId = tabs[activeIndex].id

        // Legacy migration: if old session state had inline backlog, save it to disk
        if let backlogLayout = state.backlog {
            let legacyStore = backlogLayout.toBacklogStore()
            // Save to the first tab's directory
            if let dir = tabs.first?.focusedSession?.currentDirectory {
                legacyStore.directory = dir
                BacklogFileService.shared.save(legacyStore)
            }
        }

        // Clean up saved state after successful restore
        try? FileManager.default.removeItem(at: stateFile)

        return true
    }

    func saveOnQuit() {
        // This is called from AppDelegate - we need a reference to WindowState
        // For now, we'll use NotificationCenter to request the save
        NotificationCenter.default.post(name: .saveSessionState, object: nil)
    }
}

extension Notification.Name {
    static let saveSessionState = Notification.Name("GOAT.saveSessionState")
}

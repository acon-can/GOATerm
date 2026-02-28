import Foundation

final class SessionRestorationService {
    static let shared = SessionRestorationService()

    private let stateFile: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClaudeTerm")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        stateFile = dir.appendingPathComponent("session-state.json")
    }

    struct SavedState: Codable {
        var tabs: [SavedTab]
        var activeTabIndex: Int
        var backlog: BacklogLayout?

        struct SavedTab: Codable {
            var rootPane: PaneLayout
            var focusedSessionName: String?
        }
    }

    func saveState(from windowState: WindowState) {
        let savedTabs = windowState.tabs.map { tab in
            SavedState.SavedTab(
                rootPane: PaneLayout.fromPaneNode(tab.rootPane),
                focusedSessionName: tab.focusedSession?.name
            )
        }

        let activeIndex = windowState.activeTabIndex ?? 0
        let backlogLayout = windowState.backlog.badges.isEmpty
            ? nil
            : BacklogLayout.fromBacklogStore(windowState.backlog)
        let state = SavedState(tabs: savedTabs, activeTabIndex: activeIndex, backlog: backlogLayout)

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
            return tab
        }

        windowState.tabs = tabs
        let activeIndex = min(state.activeTabIndex, tabs.count - 1)
        windowState.activeTabId = tabs[activeIndex].id

        if let backlogLayout = state.backlog {
            windowState.backlog = backlogLayout.toBacklogStore()
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
    static let saveSessionState = Notification.Name("ClaudeTerm.saveSessionState")
}

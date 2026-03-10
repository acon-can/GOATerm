import Foundation
import AppKit

enum BottomPanelMode: String, CaseIterable {
    case chat = "Chat"
    case files = "Files"
    case github = "Git"
    case servers = "Servers"
    case environment = "Env"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .github: return "arrow.triangle.branch"
        case .files: return "doc.text"
        case .servers: return "server.rack"
        case .environment: return "doc.badge.gearshape"
        case .settings: return "gear"
        }
    }
}

@Observable
final class WindowState {
    var tabs: [TabModel] = []
    var activeTabId: UUID?
    var showSaveWorkspace: Bool = false
    var showWorkspaceManager: Bool = false
    @ObservationIgnored private var backlogCache: [String: BacklogStore] = [:]
    @ObservationIgnored private var backlogCacheOrder: [String] = []
    private static let maxCacheSize = 10
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5
    var isBacklogVisible: Bool = true {
        didSet { UserDefaults.standard.set(isBacklogVisible, forKey: "panelBacklogVisible") }
    }
    var backlogWidthRatio: Double = 0.25 {
        didSet { UserDefaults.standard.set(backlogWidthRatio, forKey: "panelBacklogWidthRatio") }
    }
    var showClaudeProject: Bool = false
    var githubState: GitHubState = GitHubState()

    // Bottom panel
    var isBottomPanelExpanded: Bool {
        didSet { UserDefaults.standard.set(isBottomPanelExpanded, forKey: "panelBottomExpanded") }
    }
    var bottomPanelMode: BottomPanelMode = .chat
    var bottomPanelHeightRatio: Double {
        didSet { UserDefaults.standard.set(bottomPanelHeightRatio, forKey: "panelBottomHeightRatio") }
    }
    var savedBottomPanelHeightRatio: Double {
        didSet { UserDefaults.standard.set(savedBottomPanelHeightRatio, forKey: "panelBottomSavedRatio") }
    }

    /// Minimum backlog width ratio for a typical window (~1200px).
    /// The actual minimum is enforced as 260pt in the resize handler.
    static let defaultBacklogRatio: Double = 260.0 / 1200.0
    /// Minimum bottom panel height ratio for a typical window (~800px).
    static let defaultBottomRatio: Double = 160.0 / 800.0

    init() {
        let defaults = UserDefaults.standard

        // Restore panel layout or use sensible defaults
        if defaults.object(forKey: "panelBacklogVisible") != nil {
            self.isBacklogVisible = defaults.bool(forKey: "panelBacklogVisible")
        } else {
            self.isBacklogVisible = true
        }

        if let ratio = defaults.object(forKey: "panelBacklogWidthRatio") as? Double {
            self.backlogWidthRatio = ratio
        } else {
            self.backlogWidthRatio = Self.defaultBacklogRatio
        }

        if defaults.object(forKey: "panelBottomExpanded") != nil {
            self.isBottomPanelExpanded = defaults.bool(forKey: "panelBottomExpanded")
        } else {
            self.isBottomPanelExpanded = false
        }

        if let ratio = defaults.object(forKey: "panelBottomHeightRatio") as? Double {
            self.bottomPanelHeightRatio = ratio
        } else {
            self.bottomPanelHeightRatio = Self.defaultBottomRatio
        }

        if let ratio = defaults.object(forKey: "panelBottomSavedRatio") as? Double {
            self.savedBottomPanelHeightRatio = ratio
        } else {
            self.savedBottomPanelHeightRatio = Self.defaultBottomRatio
        }

        let firstSession = TerminalSession(color: .nextRotatingColor())
        let firstTab = TabModel(session: firstSession)
        tabs = [firstTab]
        activeTabId = firstTab.id
    }

    var activeTab: TabModel? {
        tabs.first { $0.id == activeTabId }
    }

    var activeEditorState: EditorState? { activeTab?.editorState }
    var activeServerStore: ServerStore? { activeTab?.serverStore }
    var activeChatSession: ChatSession? { activeTab?.chatSession }

    var activeTabIndex: Int? {
        tabs.firstIndex { $0.id == activeTabId }
    }

    // MARK: - Per-Directory Backlog

    var activeTerminalDirectory: String {
        activeTab?.focusedSession?.currentDirectory ?? NSHomeDirectory()
    }

    var activeBacklog: BacklogStore {
        get {
            let dir = activeTerminalDirectory
            if let cached = backlogCache[dir] {
                return cached
            }
            // Cache is @ObservationIgnored so this mutation won't trigger
            // SwiftUI re-renders — safe to do synchronously in the getter.
            let store = BacklogFileService.shared.load(from: dir)
            cacheBacklogStore(store, for: dir)
            return store
        }
        set {
            let dir = activeTerminalDirectory
            cacheBacklogStore(newValue, for: dir)
        }
    }

    private func cacheBacklogStore(_ store: BacklogStore, for directory: String) {
        backlogCache[directory] = store
        // Maintain LRU order and evict old entries
        backlogCacheOrder.removeAll { $0 == directory }
        backlogCacheOrder.append(directory)
        while backlogCacheOrder.count > Self.maxCacheSize {
            let evicted = backlogCacheOrder.removeFirst()
            backlogCache.removeValue(forKey: evicted)
            DiagnosticLogger.shared.backlog.info("Evicted backlog cache for: \(evicted, privacy: .public)")
        }
    }

    func saveActiveBacklog() {
        debouncedSave(activeBacklog)
    }

    func saveBacklog(for directory: String) {
        guard let store = backlogCache[directory] else { return }
        debouncedSave(store)
    }

    private func debouncedSave(_ store: BacklogStore) {
        pendingSaveWorkItem?.cancel()
        // Debounce fires on main thread so serialize() can safely read
        // @Observable properties; only the file I/O moves to background.
        let workItem = DispatchWorkItem { [store] in
            let log = DiagnosticLogger.shared
            log.trackRate("backlogSave", threshold: 10, windowSeconds: 10, logger: log.fileIO)
            if log.isVerbose {
                log.fileIO.debug("Saving backlog for: \(store.directory ?? "unknown", privacy: .public)")
            }
            BacklogFileService.shared.save(store)
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + saveDebounceInterval,
            execute: workItem
        )
    }

    // MARK: - Tab Operations

    func addTab(session: TerminalSession? = nil) {
        let sess = session ?? TerminalSession(color: .nextRotatingColor())
        let tab = TabModel(session: sess)
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        guard confirmCloseIfNeeded(sessions: tab.allSessions) else { return }
        performCloseTab(id: id)
    }

    func closeActiveTab() {
        guard let id = activeTabId else { return }
        closeTab(id: id)
    }

    func closeOtherTabs(keepingId: UUID) {
        let sessionsToClose = tabs.filter { $0.id != keepingId }.flatMap { $0.allSessions }
        guard confirmCloseIfNeeded(sessions: sessionsToClose) else { return }
        tabs.removeAll { $0.id != keepingId }
        activeTabId = keepingId
    }

    private func performCloseTab(id: UUID) {
        guard tabs.count > 1 else { return }
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)
            if activeTabId == id {
                let newIndex = min(index, tabs.count - 1)
                activeTabId = tabs[newIndex].id
            }
        }
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

    // MARK: - Bottom Panel

    func toggleBottomPanel() {
        if isBottomPanelExpanded {
            savedBottomPanelHeightRatio = bottomPanelHeightRatio
            isBottomPanelExpanded = false
        } else {
            bottomPanelHeightRatio = savedBottomPanelHeightRatio
            isBottomPanelExpanded = true
        }
    }

    func showBottomPanel(mode: BottomPanelMode) {
        bottomPanelMode = mode
        if !isBottomPanelExpanded {
            bottomPanelHeightRatio = savedBottomPanelHeightRatio
            isBottomPanelExpanded = true
        }
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
        // Check for running processes in the pane being closed
        if let session = tab.allSessions.first(where: { $0.id == sessionId }) {
            guard confirmCloseIfNeeded(sessions: [session]) else { return }
        }
        if !tab.closePane(sessionId: sessionId) {
            // Last pane in tab - close the tab (already confirmed above)
            guard let id = activeTabId else { return }
            performCloseTab(id: id)
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

    // MARK: - Close Confirmation

    /// Returns true if the user confirms or no processes are running.
    private func confirmCloseIfNeeded(sessions: [TerminalSession]) -> Bool {
        let running = sessions.filter { $0.runningCommand != nil }
        guard !running.isEmpty else { return true }

        let commands = running.compactMap { $0.runningCommand }
        let informative: String
        if commands.count == 1 {
            informative = "\"\(commands[0])\" is still running. Closing will terminate it."
        } else {
            informative = "\(commands.count) processes are still running. Closing will terminate them."
        }

        let alert = NSAlert()
        alert.messageText = "Close terminal?"
        alert.informativeText = informative
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }
}

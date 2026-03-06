import SwiftUI
import AppKit

// MARK: - Island Layout Constants
//
// These values define the top "island" (tab bar) geometry. They are used by
// both TabBarView (SwiftUI) and WindowConfiguratorView (AppKit) to keep the
// traffic-light buttons vertically centered in the island.
//
// ┌─ window top ──────────────────────────────────────┐
// │  outerPadding (6pt)                               │
// │  ┌─ island ─────────────────────────────────────┐ │
// │  │  innerPadding (6pt)                          │ │
// │  │  [● ● ●]  [Tab1] [Tab2] [+]          [☰]   │ │  height: 38pt
// │  │                                              │ │
// │  └──────────────────────────────────────────────┘ │
// │  outerPadding (6pt)                               │
// └───────────────────────────────────────────────────┘
//
// If you change ANY of these values, you MUST update the matching values in
// TabBarView.swift (.frame(height:), .padding(.top:), .padding(.leading:),
// and the traffic-light spacer width).

enum IslandLayout {
    /// Outer padding above and to the left of the island (matches TabBarView .padding)
    static let outerPadding: CGFloat = 6
    /// Inner content padding inside the island (matches TabBarView HStack .padding)
    static let innerPadding: CGFloat = 6
    /// Total island height (matches TabBarView .frame(height:))
    static let height: CGFloat = 38
    /// Horizontal spacing between traffic-light button centers
    static let trafficLightSpacing: CGFloat = 20

    /// Vertical center of the island, measured from the window's top edge.
    static var centerY: CGFloat { outerPadding + height / 2 }
    /// X origin of the first traffic-light button.
    static var trafficLightX: CGFloat { outerPadding + innerPadding }
}

// MARK: - Window Configurator
//
// Positions macOS traffic-light buttons (close/minimize/zoom) to sit centered
// inside the island. We observe the titlebar view's frame changes so we
// reposition the buttons every time macOS moves them (resize, fullscreen,
// tab bar changes, etc.) rather than relying on our own view's layout cycle.

class WindowConfiguratorView: NSView {
    private var observers: [NSObjectProtocol] = []
    private var isPositioning = false
    private var positionTimer: Timer?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Clean up when removed from window
        guard let window = window else {
            removeObservers()
            positionTimer?.invalidate()
            positionTimer = nil
            return
        }

        window.isMovableByWindowBackground = true
        window.title = ""
        window.titlebarAppearsTransparent = true

        // Defer initial setup to after the first layout pass
        DispatchQueue.main.async { [weak self] in
            self?.centerTrafficLights()
            self?.setupObservers()
        }
    }

    /// Watch multiple sources that can cause macOS to reset traffic-light positions.
    private func setupObservers() {
        removeObservers()
        guard let window = window,
              let button = window.standardWindowButton(.closeButton),
              let titlebarView = button.superview else { return }

        // Titlebar frame changes
        titlebarView.postsFrameChangedNotifications = true
        observers.append(NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: titlebarView,
            queue: .main
        ) { [weak self] _ in
            self?.centerTrafficLights()
        })

        // Window resize
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.centerTrafficLights()
        })

        // Window became key (e.g. after sheet dismissal)
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.centerTrafficLights()
        })

        // Polling timer — catches cases where macOS resets button positions
        // during its own layout without posting any notification.
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.centerTrafficLights()
        }
    }

    private func removeObservers() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        positionTimer?.invalidate()
        positionTimer = nil
    }

    override func layout() {
        super.layout()
        centerTrafficLights()
    }

    deinit {
        removeObservers()
    }

    private func centerTrafficLights() {
        // Guard against re-entrant calls (our positioning triggers layout
        // on the button, which could cascade back here).
        guard !isPositioning else { return }
        isPositioning = true
        defer { isPositioning = false }

        guard let window = window else { return }

        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for (index, type) in buttonTypes.enumerated() {
            guard let button = window.standardWindowButton(type) else { continue }
            guard let titlebarView = button.superview else { continue }

            let buttonMidHeight = button.frame.height / 2

            // Convert island center (measured from window top) into the
            // titlebar view's coordinate system. The titlebar view may be
            // flipped (origin at top-left) or non-flipped (origin at
            // bottom-left) depending on macOS version and window style.
            let newY: CGFloat
            if titlebarView.isFlipped {
                newY = IslandLayout.centerY - buttonMidHeight
            } else {
                newY = titlebarView.frame.height - IslandLayout.centerY - buttonMidHeight
            }

            let newX = IslandLayout.trafficLightX + CGFloat(index) * IslandLayout.trafficLightSpacing
            button.setFrameOrigin(NSPoint(x: newX, y: newY))
        }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowConfiguratorView {
        WindowConfiguratorView()
    }
    func updateNSView(_ nsView: WindowConfiguratorView, context: Context) {}
}

// MARK: - Main Window

struct MainWindowView: View {
    @Bindable var windowState: WindowState
    private let prefs = PreferencesManager.shared

    private var activeTerminalColor: TerminalColor {
        windowState.activeTab?.focusedSession?.color ?? .default
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Tab bar — sits in the titlebar area
                TabBarView(windowState: windowState)

                // Content area below titlebar
                HStack(spacing: 0) {
                    // Left column: terminal + bottom panel
                    VStack(spacing: 0) {
                        ZStack {
                            ForEach(windowState.tabs) { tab in
                                SplitContainerView(
                                    paneNode: tab.rootPane,
                                    focusedSessionId: tab.focusedSessionId,
                                    onFocusSession: { sessionId in
                                        tab.focusedSessionId = sessionId
                                    },
                                    onProcessExit: { sessionId in
                                        // Process exited - session handles the state
                                    }
                                )
                                .opacity(tab.id == windowState.activeTabId ? 1 : 0)
                                .allowsHitTesting(tab.id == windowState.activeTabId)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        )
                        .padding(.leading, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Resize handle / spacer between terminal and bottom panel
                        if windowState.isBottomPanelExpanded {
                            BottomPanelResizeHandle(
                                windowState: windowState,
                                totalHeight: geometry.size.height
                            )
                            .frame(height: 6)
                            .padding(.leading, 6)
                        } else {
                            Spacer().frame(height: 6)
                        }

                        BottomPanelView(
                            windowState: windowState,
                            totalHeight: geometry.size.height
                        )
                        .frame(height: windowState.isBottomPanelExpanded
                            ? geometry.size.height * windowState.bottomPanelHeightRatio
                            : nil)
                        .fixedSize(horizontal: false, vertical: !windowState.isBottomPanelExpanded)
                        .padding(.leading, 6)
                        .padding(.bottom, 6)
                    }

                    // Right column: backlog with resize handle
                    if windowState.isBacklogVisible {
                        BacklogResizeHandle(windowState: windowState, totalWidth: geometry.size.width)
                            .frame(width: 6)

                        KanbanBoardView(windowState: windowState)
                            .frame(width: max(260, geometry.size.width * windowState.backlogWidthRatio))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .padding(.trailing, 6)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background {
            if prefs.dynamicWindowColor && activeTerminalColor != .default {
                activeTerminalColor.swiftUIColor
                    .opacity(0.06)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.4), value: activeTerminalColor)
            }
        }
        .background(WindowConfigurator())
        .onChange(of: windowState.activeTerminalDirectory) { oldDir, newDir in
            guard oldDir != newDir else { return }
            let log = DiagnosticLogger.shared
            log.trackRate("activeTerminalDirectoryChange", threshold: 5, windowSeconds: 3, logger: log.observation)
            if log.isVerbose {
                log.observation.debug("Directory changed: \(oldDir, privacy: .public) → \(newDir, privacy: .public)")
            }
            windowState.saveBacklog(for: oldDir)
        }
        .onChange(of: windowState.activeTabId) { _, _ in
            focusActiveTerminal()
        }
        .onChange(of: windowState.activeTab?.focusedSessionId) { _, _ in
            focusActiveTerminal()
        }
        .sheet(isPresented: $windowState.showWorkspaceManager) {
            WorkspaceManagerView(windowState: windowState)
        }
        .sheet(isPresented: $windowState.showSaveWorkspace) {
            SaveWorkspaceSheet(windowState: windowState)
        }
        .sheet(isPresented: $windowState.showClaudeProject) {
            ClaudeProjectView(
                directory: windowState.activeTab?.focusedSession?.currentDirectory ?? NSHomeDirectory()
            )
        }
    }

    private func focusActiveTerminal() {
        guard let tab = windowState.activeTab,
              let sessionId = tab.focusedSessionId,
              let coordinator = TerminalPaneView.Coordinator.coordinators[sessionId],
              let terminalView = coordinator.terminalView else { return }
        DispatchQueue.main.async {
            terminalView.window?.makeFirstResponder(terminalView)
        }
    }
}

// MARK: - Backlog Resize Handle

struct BacklogResizeHandle: NSViewRepresentable {
    @Bindable var windowState: WindowState
    let totalWidth: CGFloat

    static let minWidth: CGFloat = 260

    func makeNSView(context: Context) -> BacklogResizeNSView {
        let view = BacklogResizeNSView()
        view.onDrag = { delta in
            let ratioChange = -delta / totalWidth
            let newRatio = windowState.backlogWidthRatio + ratioChange
            let minRatio = Self.minWidth / totalWidth
            windowState.backlogWidthRatio = min(max(newRatio, minRatio), 0.50)
        }
        return view
    }

    func updateNSView(_ nsView: BacklogResizeNSView, context: Context) {
        nsView.onDrag = { delta in
            let ratioChange = -delta / totalWidth
            let newRatio = windowState.backlogWidthRatio + ratioChange
            let minRatio = Self.minWidth / totalWidth
            windowState.backlogWidthRatio = min(max(newRatio, minRatio), 0.50)
        }
    }
}

class BacklogResizeNSView: NSView {
    var onDrag: ((CGFloat) -> Void)?
    private var lastX: CGFloat = 0

    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        lastX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        let currentX = event.locationInWindow.x
        let delta = currentX - lastX
        lastX = currentX
        onDrag?(delta)
    }
}

struct SaveWorkspaceSheet: View {
    @Bindable var windowState: WindowState
    @State private var workspaceName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Workspace")
                .font(.headline)

            TextField("Workspace Name", text: $workspaceName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let layout = WorkspaceLayout.capture(from: windowState, name: workspaceName)
                    WorkspacePersistenceService.shared.save(workspace: layout)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(workspaceName.isEmpty)
            }
        }
        .padding(24)
    }
}

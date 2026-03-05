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
    private var titlebarObserver: NSObjectProtocol?
    private var isPositioning = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Clean up observer when removed from window
        guard let window = window else {
            removeTitlebarObserver()
            return
        }

        window.isMovableByWindowBackground = true
        window.title = ""
        window.titlebarAppearsTransparent = true

        // Defer initial setup to after the first layout pass, so titlebar
        // geometry is finalized and button.superview is available.
        DispatchQueue.main.async { [weak self] in
            self?.centerTrafficLights()
            self?.observeTitlebar()
        }
    }

    /// Watch the titlebar view for frame changes. macOS repositions the
    /// traffic-light buttons during its own layout; this lets us fix them
    /// immediately afterward, every time.
    private func observeTitlebar() {
        removeTitlebarObserver()
        guard let window = window,
              let button = window.standardWindowButton(.closeButton),
              let titlebarView = button.superview else { return }

        titlebarView.postsFrameChangedNotifications = true
        titlebarObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: titlebarView,
            queue: .main
        ) { [weak self] _ in
            self?.centerTrafficLights()
        }
    }

    private func removeTitlebarObserver() {
        if let observer = titlebarObserver {
            NotificationCenter.default.removeObserver(observer)
            titlebarObserver = nil
        }
    }

    /// Fallback: also reposition on our own layout, in case the titlebar
    /// observer misses an edge case (e.g. first appearance).
    override func layout() {
        super.layout()
        centerTrafficLights()
    }

    deinit {
        removeTitlebarObserver()
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
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

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

                    // Right column: backlog
                    if windowState.isBacklogVisible {
                        KanbanBoardView(windowState: windowState)
                            .frame(width: geometry.size.width * windowState.backlogWidthRatio)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .padding(.trailing, 6)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowConfigurator())
        .onChange(of: windowState.activeTerminalDirectory) { oldDir, newDir in
            guard oldDir != newDir else { return }
            windowState.saveBacklog(for: oldDir)
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

import SwiftUI
import AppKit

// MARK: - Window Configurator

class WindowConfiguratorView: NSView {
    private var layoutWorkItem: DispatchWorkItem?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window else { return }
        window.isMovableByWindowBackground = true
        window.title = ""
        window.titlebarAppearsTransparent = true
        DispatchQueue.main.async { self.centerTrafficLights() }
    }

    override func layout() {
        super.layout()
        // Debounce: defer positioning until after the layout pass settles,
        // so titlebar geometry is finalized.
        layoutWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.centerTrafficLights()
        }
        layoutWorkItem = work
        DispatchQueue.main.async(execute: work)
    }

    private func centerTrafficLights() {
        guard let window = window else { return }
        // Island: 6px outer padding, 38px tall → center at y=25 from window top
        let islandCenterY: CGFloat = 25
        // 6px outer padding + 6px inner padding = 12px from window left edge
        let targetLeftX: CGFloat = 12
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for (index, type) in buttonTypes.enumerated() {
            guard let button = window.standardWindowButton(type) else { continue }
            guard let titlebarView = button.superview else { continue }
            let buttonMidHeight = button.frame.height / 2
            let newY: CGFloat
            if titlebarView.isFlipped {
                newY = islandCenterY - buttonMidHeight
            } else {
                newY = titlebarView.frame.height - islandCenterY - buttonMidHeight
            }
            let newX = targetLeftX + CGFloat(index) * 20
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

import SwiftUI

struct MainWindowView: View {
    @Bindable var windowState: WindowState

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBarView(windowState: windowState)

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            // Terminal content + optional backlog panel
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Terminal + editor area (vertical split)
                    VSplitView {
                        // Terminal area
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Agent panel (bottom bar)
                        if windowState.agentStore.isVisible {
                            AgentPanelView(agentStore: windowState.agentStore)
                                .frame(minHeight: 100, idealHeight: 200, maxHeight: 300)
                        }

                        // Editor panel (below terminal)
                        if windowState.editorState.isVisible {
                            EditorPanelView(editorState: windowState.editorState)
                                .frame(minHeight: 150, idealHeight: 300, maxHeight: 500)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if windowState.isBacklogVisible {
                        BacklogDividerView(
                            windowState: windowState,
                            totalWidth: geometry.size.width
                        )

                        BacklogPanelView(windowState: windowState)
                            .frame(width: geometry.size.width * windowState.backlogWidthRatio)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
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

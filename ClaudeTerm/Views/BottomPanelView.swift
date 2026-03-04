import SwiftUI
import AppKit

// MARK: - Bottom Panel Resize Handle

struct BottomPanelResizeHandle: View {
    @Bindable var windowState: WindowState
    let totalHeight: CGFloat

    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 6)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let delta = -value.translation.height / totalHeight
                        let newRatio = windowState.bottomPanelHeightRatio + delta
                        windowState.bottomPanelHeightRatio = min(max(newRatio, 0.15), 0.60)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

// MARK: - Bottom Panel View

struct BottomPanelView: View {
    @Bindable var windowState: WindowState
    let totalHeight: CGFloat

    private var activeColor: Color {
        let tabColor = windowState.activeTab?.color ?? .default
        return tabColor == .default ? .accentColor : tabColor.swiftUIColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // Draggable resize handle (only when expanded)
            if windowState.isBottomPanelExpanded {
                BottomPanelResizeHandle(windowState: windowState, totalHeight: totalHeight)
            }

            // Tab bar
            HStack(spacing: 8) {
                PillTabTrack {
                    ForEach(BottomPanelMode.allCases, id: \.self) { mode in
                        Button(action: {
                            if windowState.isBottomPanelExpanded {
                                windowState.bottomPanelMode = mode
                            } else {
                                windowState.bottomPanelMode = mode
                                windowState.bottomPanelHeightRatio = windowState.savedBottomPanelHeightRatio
                                windowState.isBottomPanelExpanded = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(PreferencesManager.uiFont(size: 10))
                                Text(mode.rawValue)
                                    .font(PreferencesManager.uiFont(size: 11))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PanelTabButtonStyle(
                            isActive: windowState.isBottomPanelExpanded && windowState.bottomPanelMode == mode,
                            activeColor: activeColor
                        ))
                    }
                }
                Spacer()

                // Save/Discard buttons when editing a file in Files mode
                if windowState.isBottomPanelExpanded,
                   windowState.bottomPanelMode == .files,
                   let file = windowState.activeEditorState?.activeFile,
                   file.isDirty {
                    Button(action: {
                        if let data = FileManager.default.contents(atPath: file.path),
                           let content = String(data: data, encoding: .utf8) {
                            file.content = content
                            file.isDirty = false
                        }
                    }) {
                        Text("Discard")
                            .font(PreferencesManager.uiFont(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Discard changes")

                    Button(action: {
                        file.save()
                    }) {
                        Text("Save")
                            .font(PreferencesManager.uiFont(size: 10))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Save file")
                }

                // Save/Discard buttons when editing in Environment mode
                if windowState.isBottomPanelExpanded,
                   windowState.bottomPanelMode == .environment,
                   let tab = windowState.activeTab {
                    EnvironmentDirtyButtons(
                        envState: tab.envEditorState,
                        serverStore: tab.serverStore,
                        currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory(),
                        onSwitchToServers: { windowState.bottomPanelMode = .servers }
                    )
                }

                // Refresh button for Servers mode
                if windowState.isBottomPanelExpanded,
                   windowState.bottomPanelMode == .servers,
                   let tab = windowState.activeTab {
                    Button(action: {
                        Task {
                            await ServerDiscoveryService.shared.discoverServers(
                                in: tab.focusedSession?.currentDirectory ?? NSHomeDirectory(),
                                store: tab.serverStore
                            )
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Rescan README.md")
                }

                // Refresh button for Environment mode
                if windowState.isBottomPanelExpanded,
                   windowState.bottomPanelMode == .environment {
                    Button(action: {
                        // Trigger a rescan by toggling the mode (the panel's onAppear/onChange handles it)
                        // We'll post a notification instead
                        NotificationCenter.default.post(name: .envRescanRequested, object: nil)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Rescan directory")
                }

                // Expand/collapse button
                Button(action: {
                    windowState.toggleBottomPanel()
                }) {
                    Image(systemName: "rectangle.bottomhalf.inset.filled")
                        .font(.system(size: 10))
                        .foregroundColor(windowState.isBottomPanelExpanded ? .accentColor : .secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .help(windowState.isBottomPanelExpanded ? "Collapse panel" : "Expand panel")
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)

            // Content (only when expanded)
            if windowState.isBottomPanelExpanded {
                panelContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(windowState.activeTabId)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
        .onChange(of: windowState.activeTab?.focusedSession?.currentDirectory) { _, newDir in
            if let dir = newDir {
                windowState.activeTab?.editorState.rootDirectory = dir
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if let tab = windowState.activeTab {
            switch windowState.bottomPanelMode {
            case .chat:
                AIChatView(
                    chatSession: tab.chatSession,
                    terminalSession: tab.focusedSession,
                    gitInfo: windowState.githubState.localGitInfo,
                    servers: tab.serverStore.servers,
                    backlogContext: windowState.activeBacklog.copyAllText
                )
            case .github:
                GitHubPanelView(
                    githubState: windowState.githubState,
                    currentDirectory: tab.focusedSession?.currentDirectory
                )
            case .files:
                EditorPanelView(editorState: tab.editorState)
            case .servers:
                ServerPanelView(
                    serverStore: tab.serverStore,
                    currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory()
                )
            case .environment:
                EnvironmentPanelView(
                    envState: tab.envEditorState,
                    serverStore: tab.serverStore,
                    currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory(),
                    onSwitchToServers: { windowState.bottomPanelMode = .servers }
                )
            }
        }
    }
}

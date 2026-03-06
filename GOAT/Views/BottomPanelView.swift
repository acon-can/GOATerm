import SwiftUI
import AppKit

extension Notification.Name {
    static let bottomPanelTapped = Notification.Name("bottomPanelTapped")
}

// MARK: - Bottom Panel Resize Handle

struct BottomPanelResizeHandle: NSViewRepresentable {
    @Bindable var windowState: WindowState
    let totalHeight: CGFloat

    func makeNSView(context: Context) -> BottomPanelResizeNSView {
        let view = BottomPanelResizeNSView()
        view.onDrag = makeDragHandler()
        return view
    }

    func updateNSView(_ nsView: BottomPanelResizeNSView, context: Context) {
        nsView.onDrag = makeDragHandler()
    }

    private func makeDragHandler() -> (CGFloat) -> Void {
        { delta in
            let ratioChange = delta / totalHeight
            let newRatio = windowState.bottomPanelHeightRatio + ratioChange
            let minRatio = 160 / totalHeight
            windowState.bottomPanelHeightRatio = min(max(newRatio, minRatio), 0.60)
        }
    }
}

class BottomPanelResizeNSView: NSView {
    var onDrag: ((CGFloat) -> Void)?
    private var lastY: CGFloat = 0

    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        lastY = event.locationInWindow.y
    }

    override func mouseDragged(with event: NSEvent) {
        let currentY = event.locationInWindow.y
        let delta = currentY - lastY
        lastY = currentY
        onDrag?(delta)
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
        ZStack(alignment: .top) {
            // Content — fills entire area behind the tab bar
            if windowState.isBottomPanelExpanded {
                panelContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(windowState.activeTabId)
                    .simultaneousGesture(TapGesture().onEnded {
                        NotificationCenter.default.post(name: .bottomPanelTapped, object: nil)
                    })
            }

            // Floating tab bar
            tabBarContent
                .background {
                    if windowState.isBottomPanelExpanded && windowState.bottomPanelMode == .chat {
                        Rectangle().fill(.thickMaterial)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.75), location: 0),
                                        .init(color: .black.opacity(0.5), location: 0.7),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
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
    private var tabBarContent: some View {
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
                    let name = (file.path as NSString).lastPathComponent
                    if name == "CLAUDE.md" || name == "settings.json" || name == "settings.local.json" {
                        EnvironmentEditorState.promptClaudeCodeRestart()
                    }
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
                    afterSave: {
                        EnvironmentEditorState.promptServerRestart(
                            serverStore: tab.serverStore,
                            currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory(),
                            onSwitchToServers: { windowState.bottomPanelMode = .servers }
                        )
                    }
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
                    NotificationCenter.default.post(name: .envRescanRequested, object: nil)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .help("Rescan directory")
            }

            // Save/Discard buttons when editing in Settings mode
            if windowState.isBottomPanelExpanded,
               windowState.bottomPanelMode == .settings,
               let tab = windowState.activeTab {
                EnvironmentDirtyButtons(
                    envState: tab.settingsEditorState,
                    afterSave: {
                        EnvironmentEditorState.promptClaudeCodeRestart()
                    }
                )
            }

            // Refresh button for Settings mode
            if windowState.isBottomPanelExpanded,
               windowState.bottomPanelMode == .settings {
                Button(action: {
                    NotificationCenter.default.post(name: .settingsRescanRequested, object: nil)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .help("Rescan directory")
            }

            // Expand/collapse button — aligned with submit button below
            Button(action: {
                windowState.toggleBottomPanel()
            }) {
                Image(systemName: "rectangle.bottomhalf.inset.filled")
                    .font(.system(size: 10))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .buttonStyle(PanelTabButtonStyle(
                isActive: windowState.isBottomPanelExpanded,
                activeColor: activeColor
            ))
            .help(windowState.isBottomPanelExpanded ? "Collapse panel" : "Expand panel")
        }
        .padding(.leading, 8)
        .padding(.trailing, 28)
        .padding(.top, 6)
        .padding(.bottom, 4)
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
                    serverStore: tab.serverStore,
                    currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory(),
                    backlogContext: windowState.activeBacklog.copyAllText,
                    onServerStarted: { windowState.bottomPanelMode = .servers }
                )
            case .github:
                GitHubPanelView(
                    githubState: windowState.githubState,
                    currentDirectory: tab.focusedSession?.currentDirectory
                )
                .padding(.top, 36)
            case .files:
                EditorPanelView(editorState: tab.editorState)
                    .padding(.top, 36)
            case .servers:
                ServerPanelView(
                    serverStore: tab.serverStore,
                    currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory()
                )
                .padding(.top, 36)
            case .environment:
                EnvironmentPanelView(
                    envState: tab.envEditorState,
                    serverStore: tab.serverStore,
                    currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory(),
                    onSwitchToServers: { windowState.bottomPanelMode = .servers }
                )
                .padding(.top, 36)
            case .settings:
                SettingsPanelView(
                    settingsState: tab.settingsEditorState,
                    serverStore: tab.serverStore,
                    currentDirectory: tab.focusedSession?.currentDirectory ?? NSHomeDirectory(),
                    onSwitchToServers: { windowState.bottomPanelMode = .servers }
                )
                .padding(.top, 36)
            }
        }
    }
}

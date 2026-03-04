import SwiftUI

@main
struct ClaudeTermApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var windowState = WindowState()

    var body: some Scene {
        WindowGroup {
            MainWindowView(windowState: windowState)
                .frame(minWidth: 600, minHeight: 400)
                .task {
                    // Start GitHub polling if authenticated
                    if await GitHubService.isAuthenticated() {
                        await MainActor.run { windowState.githubState.isAuthenticated = true }
                        GitHubPollingService.shared.startPolling(state: windowState.githubState)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    windowState.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    windowState.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Split Horizontally") {
                    windowState.splitActivePane(orientation: .horizontal)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Split Vertically") {
                    windowState.splitActivePane(orientation: .vertical)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Close Pane") {
                    windowState.closeActivePane()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }

            CommandGroup(after: .windowArrangement) {
                Section {
                    ForEach(1...9, id: \.self) { index in
                        Button("Tab \(index)") {
                            windowState.switchToTab(at: index - 1)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                    }
                }

                Divider()

                Button("Previous Tab") {
                    windowState.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Next Tab") {
                    windowState.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Divider()

                Button("Previous Pane") {
                    windowState.focusPreviousPane()
                }
                .keyboardShortcut("[", modifiers: [.command, .option])

                Button("Next Pane") {
                    windowState.focusNextPane()
                }
                .keyboardShortcut("]", modifiers: [.command, .option])
            }

            CommandGroup(replacing: .help) {
                Button("Toggle Kanban Board") {
                    windowState.toggleBacklog()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Toggle Bottom Panel") {
                    windowState.toggleBottomPanel()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                Button("Show Files") {
                    windowState.showBottomPanel(mode: .files)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Show Servers") {
                    windowState.showBottomPanel(mode: .servers)
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])

                Button("Show Environment") {
                    windowState.showBottomPanel(mode: .environment)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Claude Project Settings") {
                    windowState.showClaudeProject = true
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])

                Divider()

                Button("Save File") {
                    windowState.activeTab?.editorState.activeFile?.save()
                }
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                Menu("Workspaces") {
                    Button("Save Current Workspace...") {
                        windowState.showSaveWorkspace = true
                    }

                    Button("Manage Workspaces...") {
                        windowState.showWorkspaceManager = true
                    }
                }
            }
        }

        Settings {
            PreferencesView()
        }
    }
}

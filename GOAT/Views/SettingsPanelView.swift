import SwiftUI
import AppKit

extension Notification.Name {
    static let settingsRescanRequested = Notification.Name("settingsRescanRequested")
}

struct SettingsPanelView: View {
    @Bindable var settingsState: EnvironmentEditorState
    @Bindable var serverStore: ServerStore
    let currentDirectory: String
    let onSwitchToServers: () -> Void

    @State private var settingsFiles: [String] = []
    @State private var showCreateLocalSettings = false

    private static let matchedFiles: Set<String> = [
        "settings.json", "settings.local.json"
    ]

    var body: some View {
        HSplitView {
            if !settingsFiles.isEmpty {
                fileListPanel
                    .frame(minWidth: 150, idealWidth: 200, maxWidth: 250)
            }

            mainPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear { scanForSettingsFiles() }
        .onChange(of: currentDirectory) { _, _ in scanForSettingsFiles() }
        .onReceive(NotificationCenter.default.publisher(for: .settingsRescanRequested)) { _ in
            scanForSettingsFiles()
        }
    }

    // MARK: - Left Panel

    @ViewBuilder
    private var fileListPanel: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(settingsFiles, id: \.self) { file in
                    let fileName = (file as NSString).lastPathComponent
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(fileName)
                            .font(PreferencesManager.uiFont(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(settingsState.selectedFile == file ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { settingsState.selectFile(file) }
                }
            }
            .padding(.vertical, 4)

            let localPath = (currentDirectory as NSString).appendingPathComponent("settings.local.json")
            if !FileManager.default.fileExists(atPath: localPath) {
                Divider().padding(.horizontal, 8)
                createLocalSettingsButton
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Main Panel

    @ViewBuilder
    private var mainPanel: some View {
        if settingsFiles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("No settings.json or settings.local.json found")
                    .font(.caption)
                    .foregroundColor(.secondary)

                createLocalSettingsButton
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .alert("Enable Bypass Permissions?", isPresented: $showCreateLocalSettings) {
                Button("Yes, bypass all") { createLocalSettingsFile(bypassAll: true) }
                Button("No, keep defaults") { createLocalSettingsFile(bypassAll: false) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Would you like to set defaultMode to \"bypassPermissions\" in settings.local.json? This allows Claude Code to run without permission prompts.")
            }
        } else {
            editorPanel
                .alert("Enable Bypass Permissions?", isPresented: $showCreateLocalSettings) {
                    Button("Yes, bypass all") { createLocalSettingsFile(bypassAll: true) }
                    Button("No, keep defaults") { createLocalSettingsFile(bypassAll: false) }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Would you like to set defaultMode to \"bypassPermissions\" in settings.local.json? This allows Claude Code to run without permission prompts.")
                }
        }
    }

    private var createLocalSettingsButton: some View {
        let localPath = (currentDirectory as NSString).appendingPathComponent("settings.local.json")
        let alreadyExists = FileManager.default.fileExists(atPath: localPath)
        return Button(action: { showCreateLocalSettings = true }) {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
                Text("Create settings.local.json")
                    .font(PreferencesManager.uiFont(size: 11, weight: .medium))
            }
        }
        .buttonStyle(HoverButtonStyle())
        .disabled(alreadyExists)
        .help(alreadyExists ? "settings.local.json already exists" : "Create a new settings.local.json in the current directory")
    }

    // MARK: - Editor Panel

    @ViewBuilder
    private var editorPanel: some View {
        if let file = settingsState.selectedFile {
            VStack(spacing: 0) {
                HStack {
                    Text((file as NSString).lastPathComponent)
                        .font(PreferencesManager.uiFont(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()

                TextEditor(text: $settingsState.editorContent)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: settingsState.editorContent) { _, _ in
                        settingsState.updateDirty()
                    }
            }
        } else {
            Text("Select a file to edit")
                .font(PreferencesManager.uiFont(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private func createLocalSettingsFile(bypassAll: Bool) {
        let path = (currentDirectory as NSString).appendingPathComponent("settings.local.json")
        let content: String
        if bypassAll {
            content = """
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
"""
        } else {
            content = """
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
"""
        }
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            scanForSettingsFiles()
            settingsState.selectFile(path)
            EnvironmentEditorState.promptClaudeCodeRestart()
        } catch {}
    }

    private func scanForSettingsFiles() {
        let fm = FileManager.default
        do {
            let items = try fm.contentsOfDirectory(atPath: currentDirectory)
            settingsFiles = items
                .filter { Self.matchedFiles.contains($0) }
                .sorted()
                .map { (currentDirectory as NSString).appendingPathComponent($0) }
        } catch {
            settingsFiles = []
        }

        if let sel = settingsState.selectedFile, !settingsFiles.contains(sel) {
            settingsState.selectedFile = nil
            settingsState.editorContent = ""
            settingsState.originalContent = ""
            settingsState.isDirty = false
        }
    }
}

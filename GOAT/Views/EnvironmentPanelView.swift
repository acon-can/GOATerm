import SwiftUI
import AppKit

extension Notification.Name {
    static let envRescanRequested = Notification.Name("envRescanRequested")
}

struct EnvironmentPanelView: View {
    @Bindable var envState: EnvironmentEditorState
    @Bindable var serverStore: ServerStore
    let currentDirectory: String
    let onSwitchToServers: () -> Void

    @State private var envFiles: [String] = []

    var body: some View {
        HSplitView {
            // Left panel: .env file list (only if files exist)
            if !envFiles.isEmpty {
                fileListPanel
                    .frame(minWidth: 150, idealWidth: 200, maxWidth: 250)
            }

            // Right panel: editor or empty state
            mainPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear { scanForEnvFiles() }
        .onChange(of: currentDirectory) { _, _ in scanForEnvFiles() }
        .onReceive(NotificationCenter.default.publisher(for: .envRescanRequested)) { _ in
            scanForEnvFiles()
        }
    }

    // MARK: - Left Panel (file list only, no header)

    @ViewBuilder
    private var fileListPanel: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(envFiles, id: \.self) { file in
                    let fileName = (file as NSString).lastPathComponent
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(fileName)
                            .font(PreferencesManager.uiFont(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(envState.selectedFile == file ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { envState.selectFile(file) }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Main Panel

    @ViewBuilder
    private var mainPanel: some View {
        if envFiles.isEmpty {
            // Empty state in main area
            Text("No .env files found")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            editorPanel
        }
    }

    // MARK: - Right Panel

    @ViewBuilder
    private var editorPanel: some View {
        if let file = envState.selectedFile {
            VStack(spacing: 0) {
                // Header with file name
                HStack {
                    Text((file as NSString).lastPathComponent)
                        .font(PreferencesManager.uiFont(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()

                TextEditor(text: $envState.editorContent)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: envState.editorContent) { _, _ in
                        envState.updateDirty()
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

    private func scanForEnvFiles() {
        let fm = FileManager.default
        do {
            let items = try fm.contentsOfDirectory(atPath: currentDirectory)
            envFiles = items
                .filter { $0.hasPrefix(".env") }
                .sorted()
                .map { (currentDirectory as NSString).appendingPathComponent($0) }
        } catch {
            envFiles = []
        }

        if let sel = envState.selectedFile, !envFiles.contains(sel) {
            envState.selectedFile = nil
            envState.editorContent = ""
            envState.originalContent = ""
            envState.isDirty = false
        }
    }
}

// MARK: - Dirty Buttons for Bottom Panel Tab Bar

struct EnvironmentDirtyButtons: View {
    @Bindable var envState: EnvironmentEditorState
    var afterSave: (() -> Void)?

    var body: some View {
        if envState.isDirty {
            Button(action: { envState.discard() }) {
                Text("Discard")
                    .font(PreferencesManager.uiFont(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(HoverButtonStyle())
            .help("Discard changes")

            Button(action: {
                envState.save(afterSave: afterSave)
            }) {
                Text("Save")
                    .font(PreferencesManager.uiFont(size: 10))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(HoverButtonStyle())
            .help("Save file")
        }
    }
}

import SwiftUI

struct WorkspaceManagerView: View {
    @Bindable var windowState: WindowState
    @State private var workspaces: [WorkspaceLayout] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Workspaces")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if workspaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Saved Workspaces")
                        .font(.headline)
                    Text("Save your current window layout to quickly restore it later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(workspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            onLaunch: { launchWorkspace(workspace) },
                            onDelete: { deleteWorkspace(workspace) }
                        )
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Save Current Layout...") {
                    windowState.showSaveWorkspace = true
                    dismiss()
                }

                Spacer()

                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .onAppear {
            workspaces = WorkspacePersistenceService.shared.loadAll()
        }
    }

    private func launchWorkspace(_ workspace: WorkspaceLayout) {
        let tabs = workspace.restore()
        windowState.tabs = tabs
        windowState.activeTabId = tabs.first?.id
        if let backlogLayout = workspace.backlog {
            windowState.backlog = backlogLayout.toBacklogStore()
        }
        dismiss()
    }

    private func deleteWorkspace(_ workspace: WorkspaceLayout) {
        WorkspacePersistenceService.shared.delete(id: workspace.id)
        workspaces.removeAll { $0.id == workspace.id }
    }
}

struct WorkspaceRow: View {
    let workspace: WorkspaceLayout
    let onLaunch: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.name)
                    .font(.headline)
                Text("\(workspace.tabs.count) tab\(workspace.tabs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Launch") { onLaunch() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

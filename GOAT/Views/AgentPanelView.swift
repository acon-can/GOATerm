import SwiftUI

struct ServerPanelView: View {
    @Bindable var serverStore: ServerStore
    let currentDirectory: String

    private var hasServers: Bool {
        if case .discovered = serverStore.discoveryStatus, !serverStore.servers.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        HSplitView {
            // Left panel: server list (only if servers exist)
            if hasServers {
                serverListPanel
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
            }

            // Right panel: log viewer or empty state
            mainPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            if serverStore.currentDirectory != currentDirectory {
                Task {
                    await ServerDiscoveryService.shared.discoverServers(
                        in: currentDirectory, store: serverStore
                    )
                }
            }
        }
        .onChange(of: currentDirectory) { _, newDir in
            Task {
                await ServerDiscoveryService.shared.discoverServers(
                    in: newDir, store: serverStore
                )
            }
        }
    }

    // MARK: - Left Panel (server list only, no header)

    @ViewBuilder
    private var serverListPanel: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(serverStore.servers) { server in
                    ServerRowView(
                        server: server,
                        isSelected: serverStore.selectedServer?.id == server.id,
                        currentDirectory: currentDirectory,
                        onSelect: {
                            serverStore.selectedServerId = server.id
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Main Panel

    @ViewBuilder
    private var mainPanel: some View {
        if hasServers {
            logViewerPanel
        } else {
            emptyStatePanel
        }
    }

    // MARK: - Empty State (shown in main area)

    @ViewBuilder
    private var emptyStatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch serverStore.discoveryStatus {
            case .idle, .scanning:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Scanning README...")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .noReadme:
                Text("No README.md found. Add one with server start commands to detect them here.")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .noServers:
                Text("No server commands found in README.md.")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .error(let msg):
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .discovered:
                Text("No servers available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Log Viewer

    @ViewBuilder
    private var logViewerPanel: some View {
        if let server = serverStore.selectedServer {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(server.logOutput.isEmpty
                            ? (server.status == .stopped || server.status == .error
                                ? "Press start to run this server"
                                : "Waiting for output...")
                            : server.logOutput)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .id("logBottom")
                    }
                    .onChange(of: server.logOutput) { _, _ in
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                Text("Select a server to view logs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}

// MARK: - Server Row

struct ServerRowView: View {
    @Bindable var server: ServerSession
    let isSelected: Bool
    let currentDirectory: String
    let onSelect: () -> Void

    private var statusColor: Color {
        switch server.status {
        case .stopped: return .gray
        case .starting: return .yellow
        case .running: return .green
        case .error: return .red
        case .crashed: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .font(PreferencesManager.uiFont(size: 11, weight: .medium))
                    .lineLimit(1)
                if let port = server.detectedPort {
                    Text(verbatim: ":\(port)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if server.status == .stopped || server.status == .error {
                Button(action: {
                    DevServerService.shared.start(server: server, directory: currentDirectory)
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
                .buttonStyle(HoverButtonStyle())
                .help("Start server")
            } else {
                Button(action: {
                    server.status = .stopped
                    DevServerService.shared.stop(serverId: server.id)
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                }
                .buttonStyle(HoverButtonStyle())
                .help("Stop server")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

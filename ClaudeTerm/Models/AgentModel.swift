import Foundation

enum ServerStatus: String {
    case stopped
    case starting
    case running
    case error
    case crashed
}

enum ServerDiscoveryStatus {
    case idle
    case scanning
    case discovered
    case noReadme
    case noServers
    case error(String)
}

@Observable
final class ServerSession: Identifiable {
    let id: UUID
    var name: String
    var command: String
    var status: ServerStatus
    var detectedPort: Int?
    var logOutput: String
    var autoRestart: Bool
    var restartCount: Int = 0

    init(
        id: UUID = UUID(),
        name: String = "",
        command: String = "",
        status: ServerStatus = .stopped,
        autoRestart: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.status = status
        self.detectedPort = nil
        self.logOutput = ""
        self.autoRestart = autoRestart
    }
}

@Observable
final class ServerStore {
    var servers: [ServerSession] = []
    var isVisible: Bool = false
    var selectedServerId: UUID?
    var discoveryStatus: ServerDiscoveryStatus = .idle
    var currentDirectory: String?

    var selectedServer: ServerSession? {
        if let id = selectedServerId, let server = servers.first(where: { $0.id == id }) {
            return server
        }
        return servers.first
    }

    func setDiscoveredServers(_ discovered: [(name: String, command: String)]) {
        // Stop all existing servers
        for server in servers {
            DevServerService.shared.stop(serverId: server.id)
        }
        servers = discovered.map { ServerSession(name: $0.name, command: $0.command) }
        selectedServerId = servers.first?.id
        discoveryStatus = discovered.isEmpty ? .noServers : .discovered
    }

    func removeServer(id: UUID) {
        DevServerService.shared.stop(serverId: id)
        servers.removeAll { $0.id == id }
        if selectedServerId == id {
            selectedServerId = servers.first?.id
        }
    }
}

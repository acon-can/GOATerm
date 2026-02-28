import Foundation

enum AgentStatus: String {
    case stopped
    case starting
    case running
    case error
    case crashed
}

@Observable
final class AgentSession: Identifiable {
    let id: UUID
    var name: String
    var command: String
    var status: AgentStatus
    var detectedPort: Int?
    var logOutput: String
    var autoRestart: Bool
    var restartCount: Int = 0

    init(
        id: UUID = UUID(),
        name: String = "",
        command: String = "",
        status: AgentStatus = .stopped,
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
final class AgentStore {
    var agents: [AgentSession] = []
    var isVisible: Bool = false

    @discardableResult
    func addAgent(name: String = "Server", command: String = "") -> AgentSession {
        let agent = AgentSession(name: name, command: command)
        agents.append(agent)
        return agent
    }

    func removeAgent(id: UUID) {
        DevServerService.shared.stop(agentId: id)
        agents.removeAll { $0.id == id }
    }
}

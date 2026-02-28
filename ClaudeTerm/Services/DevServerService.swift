import Foundation

final class DevServerService {
    static let shared = DevServerService()
    private var processes: [UUID: Process] = [:]
    private let maxRestarts = 3

    private let portPattern = try! NSRegularExpression(
        pattern: "(?:localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0):(\\d{2,5})",
        options: .caseInsensitive
    )

    private init() {}

    func start(agent: AgentSession, directory: String) {
        guard !agent.command.isEmpty else { return }

        agent.status = .starting
        agent.logOutput = ""
        agent.detectedPort = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", agent.command]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        // Inherit PATH
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let agentId = agent.id
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                agent.logOutput += text
                // Cap log size
                if agent.logOutput.count > 50000 {
                    agent.logOutput = String(agent.logOutput.suffix(40000))
                }

                // Detect port
                if agent.detectedPort == nil {
                    self?.detectPort(in: text, agent: agent)
                }

                if agent.status == .starting {
                    agent.status = .running
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.processes.removeValue(forKey: agentId)
                if agent.autoRestart && agent.restartCount < (self?.maxRestarts ?? 3) && agent.status != .stopped {
                    agent.status = .crashed
                    agent.restartCount += 1
                    agent.logOutput += "\n[Restarting... attempt \(agent.restartCount)/\(self?.maxRestarts ?? 3)]\n"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.start(agent: agent, directory: directory)
                    }
                } else {
                    agent.status = proc.terminationStatus == 0 ? .stopped : .error
                }
            }
        }

        do {
            try process.run()
            processes[agent.id] = process
        } catch {
            agent.status = .error
            agent.logOutput += "Failed to start: \(error.localizedDescription)\n"
        }
    }

    func stop(agentId: UUID) {
        guard let process = processes[agentId] else { return }
        process.terminate()
        processes.removeValue(forKey: agentId)
    }

    func restart(agent: AgentSession, directory: String) {
        stop(agentId: agent.id)
        agent.restartCount = 0
        start(agent: agent, directory: directory)
    }

    private func detectPort(in text: String, agent: AgentSession) {
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = portPattern.firstMatch(in: text, range: range),
           let portRange = Range(match.range(at: 1), in: text),
           let port = Int(text[portRange]) {
            agent.detectedPort = port
        }
    }
}

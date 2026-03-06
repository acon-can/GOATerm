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

    func start(server: ServerSession, directory: String) {
        guard !server.command.isEmpty else { return }

        server.status = .starting
        server.logOutput = ""
        server.detectedPort = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Use interactive login shell so .zshrc/.zprofile are sourced (nvm, homebrew, etc.)
        process.arguments = ["-ilc", server.command]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let serverId = server.id
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                server.logOutput += text
                // Cap log size
                if server.logOutput.count > 50000 {
                    server.logOutput = String(server.logOutput.suffix(40000))
                }

                // Detect port
                if server.detectedPort == nil {
                    self?.detectPort(in: text, server: server)
                }

                if server.status == .starting {
                    server.status = .running
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.processes.removeValue(forKey: serverId)
                if server.autoRestart && server.restartCount < (self?.maxRestarts ?? 3) && server.status != .stopped {
                    server.status = .crashed
                    server.restartCount += 1
                    server.logOutput += "\n[Restarting... attempt \(server.restartCount)/\(self?.maxRestarts ?? 3)]\n"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.start(server: server, directory: directory)
                    }
                } else {
                    server.status = proc.terminationStatus == 0 ? .stopped : .error
                }
            }
        }

        do {
            try process.run()
            processes[server.id] = process
        } catch {
            server.status = .error
            server.logOutput += "Failed to start: \(error.localizedDescription)\n"
        }
    }

    var hasRunningProcesses: Bool {
        !processes.isEmpty
    }

    func stop(serverId: UUID) {
        guard let process = processes.removeValue(forKey: serverId) else { return }
        killProcessTree(process)
    }

    func stopAll() {
        for (id, process) in processes {
            killProcessTree(process)
            processes.removeValue(forKey: id)
        }
    }

    func restart(server: ServerSession, directory: String) {
        server.status = .stopped
        if let process = processes.removeValue(forKey: server.id) {
            killProcessTree(process)
            server.restartCount = 0
            // Wait for process to actually terminate before starting
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                process.waitUntilExit()
                DispatchQueue.main.async {
                    self?.start(server: server, directory: directory)
                }
            }
        } else {
            server.restartCount = 0
            start(server: server, directory: directory)
        }
    }

    /// Send SIGTERM to the entire process group, then SIGKILL if still alive after 2s.
    private func killProcessTree(_ process: Process) {
        guard process.isRunning else { return }
        let pgid = process.processIdentifier
        // Kill the process group (negative pid) so child processes are included
        kill(-pgid, SIGTERM)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            if process.isRunning {
                kill(-pgid, SIGKILL)
            }
        }
    }

    private func detectPort(in text: String, server: ServerSession) {
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = portPattern.firstMatch(in: text, range: range),
           let portRange = Range(match.range(at: 1), in: text),
           let port = Int(text[portRange]) {
            server.detectedPort = port
        }
    }
}

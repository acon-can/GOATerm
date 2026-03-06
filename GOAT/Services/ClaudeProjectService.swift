import Foundation

enum ClaudeProjectService {
    static func load(from directory: String) -> ClaudeProjectConfig {
        let config = ClaudeProjectConfig()

        // Walk up the directory tree to find .claude/
        var current = directory
        while current != "/" {
            let claudeDir = (current as NSString).appendingPathComponent(".claude")
            if FileManager.default.fileExists(atPath: claudeDir) {
                config.projectRoot = current
                loadSettings(from: claudeDir, into: config)
                loadClaudeMD(from: current, into: config)
                config.isLoaded = true
                return config
            }
            current = (current as NSString).deletingLastPathComponent
        }

        return config
    }

    private static func loadSettings(from claudeDir: String, into config: ClaudeProjectConfig) {
        let settingsPath = (claudeDir as NSString).appendingPathComponent("settings.json")
        guard let data = FileManager.default.contents(atPath: settingsPath),
              let json = String(data: data, encoding: .utf8) else { return }

        config.settingsJSON = json

        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Extract skills
        if let skills = parsed["skills"] as? [String] {
            config.skills = skills
        }

        // Extract MCP servers
        if let servers = parsed["mcpServers"] as? [String: [String: Any]] {
            for (name, serverConfig) in servers {
                let command = serverConfig["command"] as? String ?? ""
                let args = serverConfig["args"] as? [String] ?? []
                config.mcpServers[name] = MCPServerInfo(name: name, command: command, args: args)
            }
        }
    }

    private static func loadClaudeMD(from projectRoot: String, into config: ClaudeProjectConfig) {
        let claudeMDPath = (projectRoot as NSString).appendingPathComponent("CLAUDE.md")
        if let data = FileManager.default.contents(atPath: claudeMDPath),
           let content = String(data: data, encoding: .utf8) {
            config.claudeMD = content
            return
        }

        // Also check .claude/CLAUDE.md
        let altPath = ((projectRoot as NSString).appendingPathComponent(".claude") as NSString).appendingPathComponent("CLAUDE.md")
        if let data = FileManager.default.contents(atPath: altPath),
           let content = String(data: data, encoding: .utf8) {
            config.claudeMD = content
        }
    }
}

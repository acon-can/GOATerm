import Foundation

@Observable
final class ClaudeProjectConfig {
    var settingsJSON: String = ""
    var claudeMD: String = ""
    var projectRoot: String = ""
    var skills: [String] = []
    var mcpServers: [String: MCPServerInfo] = [:]
    var isLoaded: Bool = false
}

struct MCPServerInfo: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    let args: [String]
}

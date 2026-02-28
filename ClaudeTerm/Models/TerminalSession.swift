import Foundation
import SwiftUI

@Observable
final class TerminalSession: Identifiable {
    let id: UUID
    var name: String
    var color: TerminalColor
    var currentDirectory: String
    var gitBranch: String?
    var runningCommand: String?
    var lastCommand: String?
    var lastExitCode: Int32?
    var isRunning: Bool
    var commandStartTime: Date?
    var hasUnseenCompletion: Bool = false
    var lastOutputContainsPermissionDenied: Bool = false

    var showSudoSuggestion: Bool {
        lastOutputContainsPermissionDenied
            && lastExitCode != nil && lastExitCode != 0
            && runningCommand == nil
    }

    init(
        id: UUID = UUID(),
        name: String = "Terminal",
        color: TerminalColor = .default,
        currentDirectory: String = NSHomeDirectory()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.currentDirectory = currentDirectory
        self.gitBranch = nil
        self.runningCommand = nil
        self.lastCommand = nil
        self.lastExitCode = nil
        self.isRunning = true
    }

    var displayTitle: String {
        let dir = (currentDirectory as NSString).lastPathComponent
        var parts: [String] = []
        if name != "Terminal" && !name.isEmpty {
            parts.append(name)
        }
        parts.append("~/\(dir)")
        if let branch = gitBranch {
            parts.append("git:\(branch)")
        }
        if let cmd = runningCommand {
            parts.append(cmd)
        }
        return parts.joined(separator: " | ")
    }

    var shortTitle: String {
        if name != "Terminal" && !name.isEmpty {
            return name
        }
        return (currentDirectory as NSString).lastPathComponent
    }
}

enum TerminalColor: String, CaseIterable, Codable {
    case `default` = "default"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case cyan = "cyan"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case gray = "gray"

    var swiftUIColor: Color {
        switch self {
        case .default: return .secondary
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return .cyan
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }
}

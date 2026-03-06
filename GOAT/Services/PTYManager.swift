import Foundation

/// Helpers for managing PTY process lifecycle
enum PTYManager {
    /// Returns the default shell for the current user
    static var defaultShell: String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }
        // Fallback chain
        for shell in ["/bin/zsh", "/bin/bash", "/bin/sh"] {
            if FileManager.default.fileExists(atPath: shell) {
                return shell
            }
        }
        return "/bin/sh"
    }

    /// Returns shell name from path (e.g., "/bin/zsh" -> "zsh")
    static func shellName(from path: String) -> String {
        return (path as NSString).lastPathComponent
    }

    /// Validates a working directory exists, falls back to home
    static func validatedWorkingDirectory(_ path: String) -> String {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            return path
        }
        return NSHomeDirectory()
    }
}

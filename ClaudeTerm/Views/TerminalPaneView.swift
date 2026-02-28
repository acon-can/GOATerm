import SwiftUI
import SwiftTerm
import AppKit

struct TerminalPaneView: NSViewRepresentable {
    let session: TerminalSession
    let isFocused: Bool
    var onProcessExit: (() -> Void)?

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        context.coordinator.terminalView = terminalView
        context.coordinator.session = session

        // Configure terminal appearance
        let prefs = PreferencesManager.shared
        let font = NSFont(name: prefs.fontName, size: prefs.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: prefs.fontSize, weight: .regular)
        terminalView.font = font
        terminalView.applyClaudeTermTheme()
        terminalView.optionAsMetaKey = prefs.optionAsMeta

        // Set delegate
        terminalView.processDelegate = context.coordinator

        // Register OSC handlers for shell integration
        context.coordinator.registerOSCHandlers(on: terminalView)

        // Prepare environment and start shell
        let shellEnv = ShellIntegrationService.shared.prepareEnvironment(
            workingDirectory: session.currentDirectory
        )

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = (shell as NSString).lastPathComponent

        terminalView.startProcess(
            executable: shell,
            args: ["--login"],
            environment: shellEnv.environment,
            execName: shellName,
            currentDirectory: shellEnv.workingDirectory
        )

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        context.coordinator.session = session

        // Apply font changes live
        let prefs = PreferencesManager.shared
        let font = NSFont(name: prefs.fontName, size: prefs.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: prefs.fontSize, weight: .regular)
        if nsView.font != font {
            nsView.font = font
        }

        // Handle focus
        if isFocused {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, onProcessExit: onProcessExit)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        static var coordinators: [UUID: Coordinator] = [:]

        var session: TerminalSession
        var onProcessExit: (() -> Void)?
        weak var terminalView: LocalProcessTerminalView?
        private var titleUpdateThrottle: DispatchWorkItem?

        init(session: TerminalSession, onProcessExit: (() -> Void)?) {
            self.session = session
            self.onProcessExit = onProcessExit
            super.init()
            Coordinator.coordinators[session.id] = self
        }

        deinit {
            Coordinator.coordinators.removeValue(forKey: session.id)
        }

        func sendText(_ text: String) {
            terminalView?.send(txt: text)
        }

        func registerOSCHandlers(on terminalView: LocalProcessTerminalView) {
            let terminal = terminalView.getTerminal()

            // OSC 1337 - iTerm2-compatible SetUserVar for git branch and running command
            terminal.registerOscHandler(code: 1337) { [weak self] data in
                self?.handleOSC1337(data)
            }

            // OSC 133 - FinalTerm semantic prompt for exit codes
            terminal.registerOscHandler(code: 133) { [weak self] data in
                self?.handleOSC133(data)
            }
        }

        private func handleOSC1337(_ data: ArraySlice<UInt8>) {
            guard let str = String(bytes: data, encoding: .utf8) else { return }

            if str.hasPrefix("SetUserVar=") {
                let payload = String(str.dropFirst("SetUserVar=".count))
                let parts = payload.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { return }
                let varName = String(parts[0])
                // Value is base64-encoded
                guard let decoded = Data(base64Encoded: String(parts[1])),
                      let value = String(data: decoded, encoding: .utf8) else { return }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    switch varName {
                    case "gitBranch":
                        self.session.gitBranch = value.isEmpty ? nil : value
                    case "currentCommand":
                        self.session.runningCommand = value.isEmpty ? nil : value
                        if !value.isEmpty {
                            self.session.lastCommand = value
                            self.session.commandStartTime = Date()
                            self.session.lastOutputContainsPermissionDenied = false
                        }
                    default:
                        break
                    }
                }
            }
        }

        private func handleOSC133(_ data: ArraySlice<UInt8>) {
            guard let str = String(bytes: data, encoding: .utf8) else { return }

            // OSC 133 ; D ; <exit_code> ST - command finished with exit code
            if str.hasPrefix("D;") {
                let codeStr = String(str.dropFirst(2))
                if let code = Int32(codeStr) {
                    // Scan terminal buffer for permission denied
                    let hasPermDenied = scanForPermissionDenied()

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.session.lastExitCode = code
                        self.session.lastOutputContainsPermissionDenied = hasPermDenied
                        self.session.runningCommand = nil

                        // F5: Notify if command ran >5s and app is not active
                        if let start = self.session.commandStartTime,
                           Date().timeIntervalSince(start) > 5,
                           let cmd = self.session.lastCommand {
                            self.session.hasUnseenCompletion = true
                            NotificationService.shared.notifyCommandComplete(
                                command: cmd,
                                exitCode: code,
                                directory: self.session.currentDirectory,
                                sessionName: self.session.name
                            )
                        }
                        self.session.commandStartTime = nil
                    }
                }
            }
        }

        private func scanForPermissionDenied() -> Bool {
            guard let terminalView = terminalView else { return false }
            let terminal = terminalView.getTerminal()
            let rows = terminal.rows
            let cols = terminal.cols
            let startRow = max(0, rows - 10)
            for row in startRow..<rows {
                guard let line = terminal.getLine(row: row) else { continue }
                let text = line.translateToString(trimRight: true, startCol: 0, endCol: cols)
                if text.contains("Permission denied") || text.contains("Operation not permitted") {
                    return true
                }
            }
            return false
        }

        // MARK: - LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Terminal resized - no action needed
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Throttle title updates
            titleUpdateThrottle?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.session.name = self?.session.name == "Terminal" ? "Terminal" : (self?.session.name ?? "Terminal")
            }
            titleUpdateThrottle = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard let directory = directory else { return }
            // Directory comes as a URI: file://hostname/path
            let path: String
            if let url = URL(string: directory), url.scheme == "file" {
                path = url.path
            } else {
                path = directory
            }
            DispatchQueue.main.async { [weak self] in
                self?.session.currentDirectory = path
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { [weak self] in
                self?.session.isRunning = false
                self?.session.lastExitCode = exitCode
                self?.onProcessExit?()
            }
        }
    }
}

extension LocalProcessTerminalView {
    func applyClaudeTermTheme() {
        // Use a light terminal theme
        let bg = NSColor.white
        let fg = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        nativeBackgroundColor = bg
        nativeForegroundColor = fg

        // Set cursor/selection color
        let cursor = NSColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 0.4)
        selectedTextBackgroundColor = cursor
    }
}

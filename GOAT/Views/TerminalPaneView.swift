import SwiftUI
import SwiftTerm
import AppKit

class TerminalContainerView: NSView {
    let terminalView: LocalProcessTerminalView
    var onMouseDown: (() -> Void)?

    // Prevent window drag from intercepting mouse events meant for the
    // terminal (text selection). Without this, isMovableByWindowBackground
    // causes click-and-drag on the terminal to move the window.
    override var mouseDownCanMoveWindow: Bool { false }

    init(terminalView: LocalProcessTerminalView) {
        self.terminalView = terminalView
        super.init(frame: .zero)
        wantsLayer = true
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            terminalView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            terminalView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            terminalView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
}

struct TerminalPaneView: NSViewRepresentable {
    let session: TerminalSession
    let isFocused: Bool
    let fontName: String
    let fontSize: CGFloat
    var onProcessExit: (() -> Void)?
    var onFocusSession: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> TerminalContainerView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.focusRingType = .none
        let container = TerminalContainerView(terminalView: terminalView)
        container.focusRingType = .none
        let coordinator = context.coordinator
        container.onMouseDown = { [weak coordinator] in
            coordinator?.onFocusSession?()
        }
        context.coordinator.terminalView = terminalView
        context.coordinator.session = session

        // Configure terminal appearance
        let prefs = PreferencesManager.shared
        let font = NSFont(name: fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font
        terminalView.applyGOATTheme()
        terminalView.optionAsMetaKey = prefs.optionAsMeta

        // Hide the always-visible legacy scroller
        DispatchQueue.main.async {
            for subview in terminalView.subviews {
                if let scroller = subview as? NSScroller {
                    scroller.scrollerStyle = .overlay
                }
            }
        }

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

        return container
    }

    func updateNSView(_ nsView: TerminalContainerView, context: Context) {
        let terminalView = nsView.terminalView
        context.coordinator.session = session

        // Apply font changes live
        let font = NSFont(name: fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if terminalView.font != font {
            terminalView.font = font
        }

        // Re-apply theme on appearance change
        terminalView.applyGOATTheme()

        // Update container background on appearance change
        nsView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Handle focus
        if isFocused {
            DispatchQueue.main.async {
                terminalView.window?.makeFirstResponder(terminalView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, onProcessExit: onProcessExit, onFocusSession: onFocusSession)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        static var coordinators: [UUID: Coordinator] = [:]

        var session: TerminalSession
        var onProcessExit: (() -> Void)?
        var onFocusSession: (() -> Void)?
        weak var terminalView: LocalProcessTerminalView?
        private var titleUpdateThrottle: DispatchWorkItem?

        init(session: TerminalSession, onProcessExit: (() -> Void)?, onFocusSession: (() -> Void)?) {
            self.session = session
            self.onProcessExit = onProcessExit
            self.onFocusSession = onFocusSession
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
                    let log = DiagnosticLogger.shared
                    switch varName {
                    case "gitBranch":
                        let newValue = value.isEmpty ? nil : value
                        guard self.session.gitBranch != newValue else { return }
                        self.session.gitBranch = newValue
                    case "currentCommand":
                        let newValue = value.isEmpty ? nil : value
                        guard self.session.runningCommand != newValue else {
                            if log.isVerbose { log.terminal.debug("Skipped redundant runningCommand set") }
                            return
                        }
                        self.session.runningCommand = newValue
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
                guard let self = self else { return }
                // Skip redundant updates — @Observable fires notifications even
                // when the value hasn't changed, which cascades through the entire
                // backlog/kanban observation chain.
                guard self.session.currentDirectory != path else {
                    if DiagnosticLogger.shared.isVerbose {
                        DiagnosticLogger.shared.terminal.debug("Skipped redundant currentDirectory set: \(path, privacy: .public)")
                    }
                    return
                }
                DiagnosticLogger.shared.trackRate("directoryChange", threshold: 10, windowSeconds: 5, logger: DiagnosticLogger.shared.terminal)
                self.session.currentDirectory = path
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
    // Prevent isMovableByWindowBackground from hijacking mouse drags
    // that should be text selection in the terminal.
    override open var mouseDownCanMoveWindow: Bool { false }

    func applyGOATTheme() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bg = NSColor.windowBackgroundColor
        let fg = isDark
            ? NSColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0)
            : NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        nativeBackgroundColor = bg
        nativeForegroundColor = fg

        let cursor = isDark
            ? NSColor(red: 0.4, green: 0.5, blue: 0.8, alpha: 0.5)
            : NSColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 0.4)
        selectedTextBackgroundColor = cursor
    }
}

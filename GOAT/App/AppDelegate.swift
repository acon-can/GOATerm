import AppKit
import SwiftTerm
import CoreText
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private(set) var updaterController: SPUStandardUpdaterController!

    /// Tracks whether the user already confirmed quit via windowShouldClose,
    /// so applicationShouldTerminate doesn't show the alert a second time.
    private var userConfirmedQuit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        registerBundledFonts()
        NotificationService.shared.requestPermission()

        // Set ourselves as delegate on the main window to intercept close
        DispatchQueue.main.async {
            NSApp.windows.first?.delegate = self
        }
    }

    private func registerBundledFonts() {
        let fontFiles = ["DMSans.ttf", "DMSans-Italic.ttf"]
        for file in fontFiles {
            if let url = Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "Fonts") ??
               Bundle.main.url(forResource: (file as NSString).deletingPathExtension, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionRestorationService.shared.saveOnQuit()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if userConfirmedQuit {
            return .terminateNow
        }

        guard shouldWarnBeforeQuitting() else {
            return .terminateNow
        }

        if showQuitAlert() {
            DevServerService.shared.stopAll()
            terminateAllTerminals()
            return .terminateNow
        }

        return .terminateCancel
    }

    // Intercept window close button — prevent closing if processes are running
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard shouldWarnBeforeQuitting() else {
            return true
        }

        if showQuitAlert() {
            userConfirmedQuit = true
            DevServerService.shared.stopAll()
            terminateAllTerminals()
            return true
        }

        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Quit Warning

    /// Only warn if there are running dev servers or a running Claude instance.
    private func shouldWarnBeforeQuitting() -> Bool {
        if DevServerService.shared.hasRunningProcesses { return true }
        if hasRunningClaudeInstance() { return true }
        return false
    }

    /// Show alert, return true if user chose Quit.
    private func showQuitAlert() -> Bool {
        var parts: [String] = []
        if hasRunningClaudeInstance() { parts.append("a Claude session") }
        if DevServerService.shared.hasRunningProcesses { parts.append("dev servers") }
        let description = parts.joined(separator: " and ")

        let alert = NSAlert()
        alert.messageText = "Quit GOAT?"
        alert.informativeText = "You have \(description) running. Quitting will terminate them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Process Helpers

    private func hasRunningClaudeInstance() -> Bool {
        for coordinator in TerminalPaneView.Coordinator.coordinators.values {
            if let cmd = coordinator.session.runningCommand,
               cmd.lowercased().hasPrefix("claude") {
                return true
            }
        }
        return false
    }

    private func terminateAllTerminals() {
        for coordinator in TerminalPaneView.Coordinator.coordinators.values {
            if let tv = coordinator.terminalView, tv.process.running {
                kill(tv.process.shellPid, SIGTERM)
            }
        }
    }
}

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Session restoration happens via WindowState init
        NotificationService.shared.requestPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionRestorationService.shared.saveOnQuit()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

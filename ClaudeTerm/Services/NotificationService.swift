import Foundation
import UserNotifications
import AppKit

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyCommandComplete(command: String, exitCode: Int32, directory: String, sessionName: String) {
        guard !NSApplication.shared.isActive else { return }

        let content = UNMutableNotificationContent()
        content.title = exitCode == 0 ? "Command completed" : "Command failed (exit \(exitCode))"
        content.body = "\(command)\nin \(directory)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}

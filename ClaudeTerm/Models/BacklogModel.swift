import Foundation

enum ItemStatus: String, Codable {
    case `default` = "default"
    case inProgress = "inProgress"
    case done = "done"

    var next: ItemStatus {
        switch self {
        case .default: return .inProgress
        case .inProgress: return .done
        case .done: return .default
        }
    }
}

@Observable
final class Bullet: Identifiable {
    let id: UUID
    var text: String
    var status: ItemStatus {
        didSet {
            doneAt = status == .done ? Date() : nil
        }
    }
    var doneAt: Date?

    init(id: UUID = UUID(), text: String = "", status: ItemStatus = .default) {
        self.id = id
        self.text = text
        self.status = status
        self.doneAt = status == .done ? Date.distantPast : nil
    }

    var isHideable: Bool {
        guard status == .done, let doneAt else { return false }
        return Date().timeIntervalSince(doneAt) >= 15
    }
}

@Observable
final class Badge: Identifiable {
    let id: UUID
    var title: String
    var bullets: [Bullet]
    var status: ItemStatus {
        didSet {
            doneAt = status == .done ? Date() : nil
        }
    }
    var doneAt: Date?

    init(id: UUID = UUID(), title: String = "", bullets: [Bullet] = [], status: ItemStatus = .default) {
        self.id = id
        self.title = title
        self.bullets = bullets
        self.status = status
        self.doneAt = status == .done ? Date.distantPast : nil
    }

    @discardableResult
    func addBullet() -> UUID {
        let bullet = Bullet()
        bullets.append(bullet)
        return bullet.id
    }

    func removeBullet(id: UUID) {
        bullets.removeAll { $0.id == id }
    }

    func moveBullet(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < bullets.count,
              toIndex >= 0, toIndex < bullets.count else { return }
        let bullet = bullets.remove(at: fromIndex)
        bullets.insert(bullet, at: toIndex)
    }

    func cycleStatus() {
        status = status.next
        for bullet in bullets {
            if bullet.status != .done {
                bullet.status = status
            }
        }
    }

    var isHideable: Bool {
        guard status == .done, let doneAt else { return false }
        return Date().timeIntervalSince(doneAt) >= 15
    }

    /// Whether all bullets are done and hideable (or badge itself is hideable)
    var allBulletsHideable: Bool {
        if bullets.isEmpty { return isHideable }
        return bullets.allSatisfy { $0.isHideable }
    }

    var copyText: String {
        var result = title
        if !bullets.isEmpty {
            result += "\n" + bullets.map { "- \($0.text)" }.joined(separator: "\n")
        }
        return result
    }
}

@Observable
final class BacklogStore {
    var badges: [Badge]
    var hideCompleted: Bool = false
    var chatSession: ChatSession = ChatSession()

    init(badges: [Badge] = []) {
        self.badges = badges
    }

    @discardableResult
    func addBadge() -> UUID {
        let badge = Badge()
        badges.append(badge)
        return badge.id
    }

    func removeBadge(id: UUID) {
        badges.removeAll { $0.id == id }
    }

    var copyAllText: String {
        badges.map { $0.copyText }.joined(separator: "\n\n")
    }

    func moveBadge(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < badges.count,
              toIndex >= 0, toIndex < badges.count else { return }
        let badge = badges.remove(at: fromIndex)
        badges.insert(badge, at: toIndex)
    }
}

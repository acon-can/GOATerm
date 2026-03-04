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

enum BacklogCategory: String, CaseIterable {
    case features = "Features"
    case bugs = "Bugs"
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
final class KanbanBoard: Identifiable {
    let id: UUID
    var name: String
    var bullets: [Bullet]
    var color: TerminalColor = .default

    init(id: UUID = UUID(), name: String = "Prompt Backlog", bullets: [Bullet] = [], color: TerminalColor = .default) {
        self.id = id
        self.name = name
        self.bullets = bullets
        self.color = color
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

    var copyAllText: String {
        bullets.map { "- \($0.text)" }.joined(separator: "\n")
    }
}

@Observable
final class BacklogStore {
    var featureBoards: [KanbanBoard]
    var bugBoards: [KanbanBoard]
    var activeCategory: BacklogCategory = .features
    var activeFeatureBoardIndex: Int = 0
    var activeBugBoardIndex: Int = 0
    var hideCompleted: Bool = true
    var directory: String?

    var boards: [KanbanBoard] {
        get {
            switch activeCategory {
            case .features: return featureBoards
            case .bugs: return bugBoards
            }
        }
        set {
            switch activeCategory {
            case .features: featureBoards = newValue
            case .bugs: bugBoards = newValue
            }
        }
    }

    var activeBoardIndex: Int {
        get {
            switch activeCategory {
            case .features: return activeFeatureBoardIndex
            case .bugs: return activeBugBoardIndex
            }
        }
        set {
            switch activeCategory {
            case .features: activeFeatureBoardIndex = newValue
            case .bugs: activeBugBoardIndex = newValue
            }
        }
    }

    var activeBoard: KanbanBoard? {
        let idx = activeBoardIndex
        let currentBoards = boards
        guard idx >= 0, idx < currentBoards.count else { return nil }
        return currentBoards[idx]
    }

    init(featureBoards: [KanbanBoard]? = nil, bugBoards: [KanbanBoard]? = nil) {
        self.featureBoards = featureBoards ?? [KanbanBoard(name: "Feature List 1")]
        self.bugBoards = bugBoards ?? [KanbanBoard(name: "Bug List 1")]
    }

    @discardableResult
    func addBoard(name: String? = nil) -> UUID {
        let defaultName: String
        switch activeCategory {
        case .features: defaultName = "Feature List \(featureBoards.count + 1)"
        case .bugs: defaultName = "Bug List \(bugBoards.count + 1)"
        }
        let board = KanbanBoard(name: name ?? defaultName)
        switch activeCategory {
        case .features: featureBoards.append(board)
        case .bugs: bugBoards.append(board)
        }
        return board.id
    }

    func removeBoard(id: UUID) {
        switch activeCategory {
        case .features:
            guard featureBoards.count > 1 else { return }
            featureBoards.removeAll { $0.id == id }
        case .bugs:
            guard bugBoards.count > 1 else { return }
            bugBoards.removeAll { $0.id == id }
        }
    }

    func bulletCount(for category: BacklogCategory) -> Int {
        switch category {
        case .features: return featureBoards.reduce(0) { $0 + $1.bullets.count }
        case .bugs: return bugBoards.reduce(0) { $0 + $1.bullets.count }
        }
    }

    var copyAllText: String {
        let allBoards = featureBoards + bugBoards
        return allBoards.flatMap { $0.bullets }.map { "- \($0.text)" }.joined(separator: "\n")
    }
}

import Foundation

struct WorkspaceLayout: Codable, Identifiable {
    var id: UUID
    var name: String
    var tabs: [TabLayout]
    var backlog: BacklogLayout?
    var createdAt: Date
    var updatedAt: Date

    struct TabLayout: Codable {
        var name: String
        var color: String
        var rootPane: PaneLayout
    }

    init(id: UUID = UUID(), name: String, tabs: [TabLayout], backlog: BacklogLayout? = nil) {
        self.id = id
        self.name = name
        self.tabs = tabs
        self.backlog = backlog
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Backlog Layout

struct BulletLayout: Codable {
    var id: UUID
    var text: String
    var status: String
}

struct BadgeLayout: Codable {
    var id: UUID
    var title: String
    var bullets: [BulletLayout]
    var status: String
}

struct BacklogLayout: Codable {
    var badges: [BadgeLayout]

    static func fromBacklogStore(_ store: BacklogStore) -> BacklogLayout {
        let badgeLayouts = store.badges.map { badge in
            BadgeLayout(
                id: badge.id,
                title: badge.title,
                bullets: badge.bullets.map { bullet in
                    BulletLayout(id: bullet.id, text: bullet.text, status: bullet.status.rawValue)
                },
                status: badge.status.rawValue
            )
        }
        return BacklogLayout(badges: badgeLayouts)
    }

    func toBacklogStore() -> BacklogStore {
        let badges = badges.map { badgeLayout in
            Badge(
                id: badgeLayout.id,
                title: badgeLayout.title,
                bullets: badgeLayout.bullets.map { bulletLayout in
                    Bullet(
                        id: bulletLayout.id,
                        text: bulletLayout.text,
                        status: ItemStatus(rawValue: bulletLayout.status) ?? .default
                    )
                },
                status: ItemStatus(rawValue: badgeLayout.status) ?? .default
            )
        }
        return BacklogStore(badges: badges)
    }
}

struct SessionConfig: Codable {
    var name: String
    var color: String
    var workingDirectory: String
    var startupCommand: String?
}

indirect enum PaneLayout: Codable {
    case terminal(SessionConfig)
    case split(orientation: String, first: PaneLayout, second: PaneLayout, ratio: Double)

    // Custom Codable to produce clean JSON
    private enum CodingKeys: String, CodingKey {
        case type, sessionConfig, splitOrientation, first, second, ratio
    }

    private enum PaneType: String, Codable {
        case terminal, split
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PaneType.self, forKey: .type)
        switch type {
        case .terminal:
            let config = try container.decode(SessionConfig.self, forKey: .sessionConfig)
            self = .terminal(config)
        case .split:
            let orientation = try container.decode(String.self, forKey: .splitOrientation)
            let first = try container.decode(PaneLayout.self, forKey: .first)
            let second = try container.decode(PaneLayout.self, forKey: .second)
            let ratio = try container.decode(Double.self, forKey: .ratio)
            self = .split(orientation: orientation, first: first, second: second, ratio: ratio)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .terminal(let config):
            try container.encode(PaneType.terminal, forKey: .type)
            try container.encode(config, forKey: .sessionConfig)
        case .split(let orientation, let first, let second, let ratio):
            try container.encode(PaneType.split, forKey: .type)
            try container.encode(orientation, forKey: .splitOrientation)
            try container.encode(first, forKey: .first)
            try container.encode(second, forKey: .second)
            try container.encode(ratio, forKey: .ratio)
        }
    }
}

// MARK: - Conversion helpers

extension PaneLayout {
    static func fromPaneNode(_ node: PaneNode) -> PaneLayout {
        switch node {
        case .terminal(let session):
            return .terminal(SessionConfig(
                name: session.name,
                color: session.color.rawValue,
                workingDirectory: session.currentDirectory,
                startupCommand: nil
            ))
        case .split(let orientation, let first, let second, let ratio):
            return .split(
                orientation: orientation.rawValue,
                first: fromPaneNode(first),
                second: fromPaneNode(second),
                ratio: ratio
            )
        }
    }

    func toPaneNode() -> PaneNode {
        switch self {
        case .terminal(let config):
            let session = TerminalSession(
                name: config.name,
                color: TerminalColor(rawValue: config.color) ?? .default,
                currentDirectory: config.workingDirectory
            )
            return .terminal(session)
        case .split(let orientation, let first, let second, let ratio):
            let orient = SplitOrientation(rawValue: orientation) ?? .horizontal
            return .split(
                orientation: orient,
                first: first.toPaneNode(),
                second: second.toPaneNode(),
                ratio: ratio
            )
        }
    }
}

extension WorkspaceLayout {
    static func capture(from windowState: WindowState, name: String) -> WorkspaceLayout {
        let tabLayouts = windowState.tabs.map { tab in
            TabLayout(
                name: tab.focusedSession?.name ?? "Terminal",
                color: tab.color.rawValue,
                rootPane: PaneLayout.fromPaneNode(tab.rootPane)
            )
        }
        let backlogLayout = windowState.backlog.badges.isEmpty
            ? nil
            : BacklogLayout.fromBacklogStore(windowState.backlog)
        return WorkspaceLayout(name: name, tabs: tabLayouts, backlog: backlogLayout)
    }

    func restore() -> [TabModel] {
        return tabs.map { tabLayout in
            let rootNode = tabLayout.rootPane.toPaneNode()
            let tab = TabModel()
            tab.rootPane = rootNode
            tab.focusedSessionId = rootNode.firstSession?.id
            return tab
        }
    }
}

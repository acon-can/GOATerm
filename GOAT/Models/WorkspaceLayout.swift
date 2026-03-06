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
        var agents: [ServerLayout]?  // legacy field name kept for backward compat decoding
    }

    struct ServerLayout: Codable {
        var name: String
        var command: String
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

struct BoardLayout: Codable {
    var id: UUID
    var name: String
    var badges: [BadgeLayout]?
    var bullets: [BulletLayout]?
    var color: String?
}

struct BacklogLayout: Codable {
    var badges: [BadgeLayout]?
    var boards: [BoardLayout]?
    var featureBoards: [BoardLayout]?
    var bugBoards: [BoardLayout]?

    static func fromBacklogStore(_ store: BacklogStore) -> BacklogLayout {
        let featureBoardLayouts = store.featureBoards.map { board in
            BoardLayout(
                id: board.id,
                name: board.name,
                badges: nil,
                bullets: board.bullets.map { bullet in
                    BulletLayout(id: bullet.id, text: bullet.text, status: bullet.status.rawValue)
                },
                color: board.color == .default ? nil : board.color.rawValue
            )
        }
        let bugBoardLayouts = store.bugBoards.map { board in
            BoardLayout(
                id: board.id,
                name: board.name,
                badges: nil,
                bullets: board.bullets.map { bullet in
                    BulletLayout(id: bullet.id, text: bullet.text, status: bullet.status.rawValue)
                },
                color: board.color == .default ? nil : board.color.rawValue
            )
        }
        return BacklogLayout(featureBoards: featureBoardLayouts, bugBoards: bugBoardLayouts)
    }

    func toBacklogStore() -> BacklogStore {
        // New format: separate feature/bug boards
        if let featureBoardLayouts = featureBoards, let bugBoardLayouts = bugBoards {
            let fBoards = featureBoardLayouts.map { decodeBoardLayout($0) }
            let bBoards = bugBoardLayouts.map { decodeBoardLayout($0) }
            return BacklogStore(
                featureBoards: fBoards.isEmpty ? nil : fBoards,
                bugBoards: bBoards.isEmpty ? nil : bBoards
            )
        }

        // Old format: single boards array → treat as feature boards
        if let boards, !boards.isEmpty {
            let kanbanBoards = boards.map { decodeBoardLayout($0) }
            return BacklogStore(featureBoards: kanbanBoards, bugBoards: nil)
        }

        // Legacy migration: single badges array becomes one feature board
        if let badges, !badges.isEmpty {
            let bullets = badges.flatMap { badgeLayout in
                badgeLayout.bullets.map { bulletLayout in
                    Bullet(
                        id: bulletLayout.id,
                        text: bulletLayout.text,
                        status: ItemStatus(rawValue: bulletLayout.status) ?? .default
                    )
                }
            }
            return BacklogStore(featureBoards: [KanbanBoard(name: "Prompt Backlog", bullets: bullets)], bugBoards: nil)
        }

        return BacklogStore()
    }

    private func decodeBoardLayout(_ boardLayout: BoardLayout) -> KanbanBoard {
        let boardColor = boardLayout.color.flatMap { TerminalColor(rawValue: $0) } ?? .default
        // New format: flat bullets array
        if let bulletLayouts = boardLayout.bullets, !bulletLayouts.isEmpty {
            let bullets = bulletLayouts.map { bulletLayout in
                Bullet(
                    id: bulletLayout.id,
                    text: bulletLayout.text,
                    status: ItemStatus(rawValue: bulletLayout.status) ?? .default
                )
            }
            return KanbanBoard(id: boardLayout.id, name: boardLayout.name, bullets: bullets, color: boardColor)
        }
        // Old format: flatten badges into flat bullet list
        if let badgeLayouts = boardLayout.badges, !badgeLayouts.isEmpty {
            let bullets = badgeLayouts.flatMap { badgeLayout in
                badgeLayout.bullets.map { bulletLayout in
                    Bullet(
                        id: bulletLayout.id,
                        text: bulletLayout.text,
                        status: ItemStatus(rawValue: bulletLayout.status) ?? .default
                    )
                }
            }
            return KanbanBoard(id: boardLayout.id, name: boardLayout.name, bullets: bullets, color: boardColor)
        }
        return KanbanBoard(id: boardLayout.id, name: boardLayout.name, color: boardColor)
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
            // Servers are discovered from README — don't embed in workspace
            return TabLayout(
                name: tab.focusedSession?.name ?? "Terminal",
                color: tab.color.rawValue,
                rootPane: PaneLayout.fromPaneNode(tab.rootPane),
                agents: nil
            )
        }
        // Backlogs now persist via backlog.goat.md — don't embed in workspace
        return WorkspaceLayout(name: name, tabs: tabLayouts, backlog: nil)
    }

    func restore() -> [TabModel] {
        return tabs.map { tabLayout in
            let rootNode = tabLayout.rootPane.toPaneNode()
            let tab = TabModel()
            tab.rootPane = rootNode
            tab.focusedSessionId = rootNode.firstSession?.id
            if let dir = rootNode.firstSession?.currentDirectory {
                tab.editorState.rootDirectory = dir
            }
            // Legacy agent configs are ignored — servers re-discovered from README
            return tab
        }
    }
}

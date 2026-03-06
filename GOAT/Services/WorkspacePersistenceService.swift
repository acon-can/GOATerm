import Foundation

final class WorkspacePersistenceService {
    static let shared = WorkspacePersistenceService()

    private let workspacesDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        workspacesDir = appSupport.appendingPathComponent("GOAT/Workspaces")
        try? FileManager.default.createDirectory(at: workspacesDir, withIntermediateDirectories: true)
    }

    func save(workspace: WorkspaceLayout) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(workspace)
            let filename = "\(workspace.id.uuidString).json"
            let url = workspacesDir.appendingPathComponent(filename)
            try data.write(to: url)
        } catch {
            print("Failed to save workspace: \(error)")
        }
    }

    func loadAll() -> [WorkspaceLayout] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: workspacesDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }

            return files.compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let workspace = try? decoder.decode(WorkspaceLayout.self, from: data) else {
                    return nil
                }
                return workspace
            }.sorted { $0.name < $1.name }
        } catch {
            return []
        }
    }

    func load(id: UUID) -> WorkspaceLayout? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = workspacesDir.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(WorkspaceLayout.self, from: data)
    }

    func delete(id: UUID) {
        let url = workspacesDir.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }
}

import Foundation

@Observable
final class EditorState {
    var isVisible: Bool = false
    var rootDirectory: String = NSHomeDirectory()
    var openFiles: [OpenFile] = []
    var activeFileId: UUID?

    var activeFile: OpenFile? {
        openFiles.first { $0.id == activeFileId }
    }

    func openFile(at path: String) {
        if let existing = openFiles.first(where: { $0.path == path }) {
            activeFileId = existing.id
            return
        }
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return }
        let file = OpenFile(path: path, content: content)
        openFiles.append(file)
        activeFileId = file.id
    }

    func closeFile(id: UUID) {
        openFiles.removeAll { $0.id == id }
        if activeFileId == id {
            activeFileId = openFiles.last?.id
        }
    }
}

@Observable
final class OpenFile: Identifiable {
    let id: UUID
    let path: String
    var content: String
    var isDirty: Bool = false

    var filename: String {
        (path as NSString).lastPathComponent
    }

    init(id: UUID = UUID(), path: String, content: String) {
        self.id = id
        self.path = path
        self.content = content
    }

    func save() {
        guard isDirty else { return }
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        isDirty = false
    }
}

@Observable
final class FileTreeNode: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileTreeNode]?
    var isExpanded: Bool = false

    init(name: String, path: String, isDirectory: Bool) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
    }

    func loadChildren() {
        guard isDirectory, children == nil else { return }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else {
            children = []
            return
        }
        children = items
            .filter { !$0.hasPrefix(".") }
            .compactMap { name -> FileTreeNode? in
                let fullPath = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { return nil }
                return FileTreeNode(name: name, path: fullPath, isDirectory: isDir.boolValue)
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory == rhs.isDirectory {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.isDirectory && !rhs.isDirectory
            }
    }
}

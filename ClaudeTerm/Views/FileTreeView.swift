import SwiftUI

struct FileTreeView: View {
    let rootNode: FileTreeNode
    let onSelectFile: (String) -> Void
    var onSetRoot: ((String) -> Void)?
    var onRename: (() -> Void)?
    var activeFilePath: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                FileTreeNodeView(
                    node: rootNode,
                    depth: 0,
                    onSelectFile: onSelectFile,
                    onSetRoot: onSetRoot,
                    onRename: onRename,
                    activeFilePath: activeFilePath
                )
            }
            .padding(.vertical, 4)
        }
    }
}

struct FileTreeNodeView: View {
    @Bindable var node: FileTreeNode
    let depth: Int
    let onSelectFile: (String) -> Void
    var onSetRoot: ((String) -> Void)?
    var onRename: (() -> Void)?
    var activeFilePath: String?
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if node.isRenaming {
                renameRow
            } else {
                normalRow
            }

            if node.isDirectory && node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeNodeView(
                        node: child,
                        depth: depth + 1,
                        onSelectFile: onSelectFile,
                        onSetRoot: onSetRoot,
                        onRename: onRename,
                        activeFilePath: activeFilePath
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var normalRow: some View {
        Button(action: {
            if node.isDirectory {
                node.loadChildren()
                withAnimation(.easeInOut(duration: 0.15)) {
                    node.isExpanded.toggle()
                }
            } else {
                onSelectFile(node.path)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: node.isDirectory
                    ? (node.isExpanded ? "folder.fill" : "folder")
                    : fileIcon(for: node.name))
                    .font(.system(size: 11))
                    .foregroundColor(node.isDirectory ? .accentColor : .secondary)
                    .frame(width: 16)

                Text(node.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, CGFloat(depth) * 16 + 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(node.path == activeFilePath && !node.isDirectory
            ? Color.accentColor.opacity(0.15)
            : Color.clear)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if node.isDirectory {
                    if node.isExpanded {
                        // Already expanded — navigate into it as new root
                        onSetRoot?(node.path)
                    }
                }
            }
        )
        .contextMenu {
            Button("Rename...") {
                node.editingName = node.name
                node.isRenaming = true
            }
        }
    }

    @ViewBuilder
    private var renameRow: some View {
        HStack(spacing: 4) {
            Image(systemName: node.isDirectory
                ? (node.isExpanded ? "folder.fill" : "folder")
                : fileIcon(for: node.name))
                .font(.system(size: 11))
                .foregroundColor(node.isDirectory ? .accentColor : .secondary)
                .frame(width: 16)

            TextField("Name", text: $node.editingName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.accentColor, lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                )
                .focused($isRenameFocused)
                .onSubmit {
                    performRename()
                }
                .onExitCommand {
                    cancelRename()
                }
                .onChange(of: isRenameFocused) { _, focused in
                    if !focused {
                        // Lost focus without submit — cancel
                        cancelRename()
                    }
                }
        }
        .padding(.leading, CGFloat(depth) * 16 + 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            isRenameFocused = true
        }
    }

    private func performRename() {
        let newName = node.editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != node.name else {
            cancelRename()
            return
        }

        let parentPath = (node.path as NSString).deletingLastPathComponent
        let newPath = (parentPath as NSString).appendingPathComponent(newName)

        do {
            try FileManager.default.moveItem(atPath: node.path, toPath: newPath)
            node.isRenaming = false
            onRename?()
        } catch {
            // Rename failed — cancel silently
            cancelRename()
        }
    }

    private func cancelRename() {
        node.editingName = ""
        node.isRenaming = false
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "doc.text"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json": return "curlybraces"
        case "md": return "doc.richtext"
        case "sh", "bash", "zsh": return "terminal"
        default: return "doc"
        }
    }
}

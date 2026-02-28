import SwiftUI

struct FileTreeView: View {
    let rootNode: FileTreeNode
    let onSelectFile: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                FileTreeNodeView(node: rootNode, depth: 0, onSelectFile: onSelectFile)
            }
            .padding(.vertical, 4)
        }
    }
}

struct FileTreeNodeView: View {
    @Bindable var node: FileTreeNode
    let depth: Int
    let onSelectFile: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            if node.isDirectory && node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeNodeView(node: child, depth: depth + 1, onSelectFile: onSelectFile)
                }
            }
        }
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

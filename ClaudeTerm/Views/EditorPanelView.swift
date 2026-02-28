import SwiftUI

struct EditorPanelView: View {
    @Bindable var editorState: EditorState

    @State private var rootNode: FileTreeNode?

    var body: some View {
        HSplitView {
            // File tree sidebar
            VStack(spacing: 0) {
                HStack {
                    Text("Files")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Divider()

                if let rootNode = rootNode {
                    FileTreeView(rootNode: rootNode) { path in
                        editorState.openFile(at: path)
                    }
                } else {
                    Text("No directory loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 150, idealWidth: 200, maxWidth: 250)

            // Editor area
            VStack(spacing: 0) {
                // File tabs
                if !editorState.openFiles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(editorState.openFiles) { file in
                                EditorTabView(
                                    file: file,
                                    isActive: file.id == editorState.activeFileId,
                                    onSelect: { editorState.activeFileId = file.id },
                                    onClose: { editorState.closeFile(id: file.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                    }
                    .background(Color(nsColor: .windowBackgroundColor))

                    Divider()
                }

                // Editor content
                if let file = editorState.activeFile {
                    CodeEditorView(
                        text: Binding(
                            get: { file.content },
                            set: { file.content = $0 }
                        ),
                        fileExtension: (file.path as NSString).pathExtension,
                        onTextChange: { _ in file.isDirty = true }
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("Select a file to edit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: editorState.rootDirectory) { _, newDir in
            loadFileTree(directory: newDir)
        }
        .onAppear {
            loadFileTree(directory: editorState.rootDirectory)
        }
    }

    private func loadFileTree(directory: String) {
        let node = FileTreeNode(
            name: (directory as NSString).lastPathComponent,
            path: directory,
            isDirectory: true
        )
        node.loadChildren()
        node.isExpanded = true
        rootNode = node
    }
}

struct EditorTabView: View {
    let file: OpenFile
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            if file.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
            Text(file.filename)
                .font(.system(size: 11))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

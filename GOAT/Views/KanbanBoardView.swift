import SwiftUI
import AppKit

// MARK: - Kanban Board View

struct KanbanBoardView: View {
    @Bindable var windowState: WindowState

    private var store: BacklogStore { windowState.activeBacklog }

    private var activeColor: Color {
        let tabColor = windowState.activeTab?.color ?? .default
        return tabColor == .default ? .accentColor : tabColor.swiftUIColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category switcher
            HStack(spacing: 8) {
                PillTabTrack {
                    ForEach(BacklogCategory.allCases, id: \.self) { category in
                        let active = store.activeCategory == category
                        let count = store.bulletCount(for: category)
                        Button {
                            store.activeCategory = category
                        } label: {
                            HStack(spacing: 4) {
                                Text(category.rawValue)
                                    .font(PreferencesManager.uiFont(size: 11, weight: active ? .semibold : .regular))
                                if count > 0 {
                                    Text("\(count)")
                                        .font(PreferencesManager.uiFont(size: 9))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PanelTabButtonStyle(isActive: active, activeColor: activeColor))
                    }
                }
                Spacer()

                // Copy active board
                if let board = store.activeBoard {
                    Button(action: {
                        let prefix = store.activeCategory == .bugs ? "BUG: " : ""
                        let unstarted = board.bullets.filter { $0.status == .default }
                        let text = unstarted.map { "- \(prefix)\($0.text)" }.joined(separator: "\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Copy unstarted as markdown")
                    .disabled(board.bullets.filter { $0.status == .default }.isEmpty)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if let board = store.activeBoard {
                KanbanColumnView(
                    board: board,
                    hideCompleted: store.hideCompleted,
                    store: store,
                    onSave: { windowState.saveActiveBacklog() }
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
        .padding(.bottom, 6)
    }
}

// MARK: - Kanban Column

struct KanbanColumnView: View {
    @Bindable var board: KanbanBoard
    var hideCompleted: Bool
    let store: BacklogStore
    var onSave: (() -> Void)?
    @State private var draggedBullet: Bullet?
    @State private var isEditingName = false
    @FocusState private var focusedField: BacklogField?
    @FocusState private var isNameFieldFocused: Bool
    @State private var hiddenBulletIds: Set<UUID> = []
    private let prefs = PreferencesManager.shared

    private var visibleBullets: [Bullet] {
        if !hideCompleted { return board.bullets }
        return board.bullets.filter { !hiddenBulletIds.contains($0.id) }
    }

    private var hiddenCount: Int {
        board.bullets.count - visibleBullets.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Column header (only when multiple boards)
            if store.boards.count > 1 {
                columnHeader
            }

            // Bullet list
            if board.bullets.isEmpty {
                emptyState
            } else {
                bulletList
            }

            // Footer with board navigation
            columnFooter
        }
        .onAppear {
            if hideCompleted {
                hiddenBulletIds = Set(board.bullets.filter { $0.isHideable }.map { $0.id })
            }
        }
        .onChange(of: board.id) { _, _ in
            if hideCompleted {
                hiddenBulletIds = Set(board.bullets.filter { $0.isHideable }.map { $0.id })
            }
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            // Auto-delete bullets that have been in deleted state for 5+ seconds
            let deletable = board.bullets.filter { $0.isDeletable }
            if !deletable.isEmpty {
                withAnimation(.easeInOut(duration: 0.25)) {
                    for bullet in deletable {
                        board.removeBullet(id: bullet.id)
                    }
                }
                onSave?()
            }

            guard hideCompleted else { return }
            let newHidden = Set(board.bullets.filter { $0.isHideable }.map { $0.id })
            if newHidden != hiddenBulletIds {
                withAnimation { hiddenBulletIds = newHidden }
            }
        }
        .onChange(of: focusedField) { old, new in
            // Save when focus leaves a bullet field
            if old != nil && new == nil {
                onSave?()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bottomPanelTapped)) { _ in
            if focusedField != nil {
                focusedField = nil
            }
        }
    }

    // MARK: - Column Header

    @ViewBuilder
    private var columnHeader: some View {
        HStack(spacing: 6) {
            if isEditingName {
                TextField("Board name", text: $board.name)
                    .textFieldStyle(.plain)
                    .font(prefs.backlogFont)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                    )
                    .focused($isNameFieldFocused)
                    .onSubmit { isEditingName = false; onSave?() }
                    .onChange(of: isNameFieldFocused) { _, focused in
                        if !focused { isEditingName = false; onSave?() }
                    }
                    .onAppear { isNameFieldFocused = true }
            } else {
                Text(board.name)
                    .font(prefs.backlogFont)
                    .foregroundColor(board.color == .default ? .primary : board.color.swiftUIColor)
                    .onTapGesture(count: 2) { isEditingName = true }
                    .contextMenu {
                        Menu("Set Color") {
                            ForEach(TerminalColor.allCases, id: \.rawValue) { color in
                                Button(action: { board.color = color }) {
                                    HStack {
                                        Circle()
                                            .fill(color.swiftUIColor)
                                            .frame(width: 10, height: 10)
                                        Text(color.rawValue.capitalized)
                                    }
                                }
                            }
                        }
                    }
            }

            Text("\(board.bullets.filter { $0.status == .default || $0.status == .inProgress }.count)")
                .font(PreferencesManager.uiFont(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.gray.opacity(0.2)))

            Spacer()

            // Delete board (only if more than one)
            if store.boards.count > 1 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        let idx = store.activeBoardIndex
                        store.removeBoard(id: board.id)
                        store.activeBoardIndex = min(idx, store.boards.count - 1)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .help("Delete board")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No prompts yet")
                .font(PreferencesManager.uiFont(size: 12))
                .foregroundColor(.secondary)
                .padding(.leading, 6)
            Text("Items are saved to **backlog.goat.md**\nin your project directory")
                .font(PreferencesManager.uiFont(size: 12))
                .foregroundColor(.secondary)
                .padding(.leading, 6)
            addPromptButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    // MARK: - Add Prompt Button

    @ViewBuilder
    private var addPromptButton: some View {
        HStack(alignment: .top, spacing: 4) {
            // Plus icon — same wrapper as status icon button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    let newId = board.addBullet()
                    focusedField = .bulletText(newId)
                }
            }) {
                Image(systemName: "plus")
                    .font(prefs.backlogFont)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(HoverButtonStyle())

            // Placeholder text — same position as TextField in BulletRowView
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    let newId = board.addBullet()
                    focusedField = .bulletText(newId)
                }
            }) {
                Text("Add prompt")
                    .font(prefs.backlogFont)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 1)
        .padding(.leading, 6)
    }

    // MARK: - Bullet List

    @ViewBuilder
    private var bulletList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(visibleBullets) { bullet in
                    BulletRowView(
                        bullet: bullet,
                        board: board,
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                board.removeBullet(id: bullet.id)
                            }
                        },
                        onSave: onSave ?? {},
                        focusedField: $focusedField,
                        isBug: store.activeCategory == .bugs
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                    .onDrag {
                        draggedBullet = bullet
                        return NSItemProvider(object: bullet.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: BoardBulletDropDelegate(
                        bullet: bullet,
                        board: board,
                        draggedBullet: $draggedBullet
                    ))
                }

                // Add prompt button
                addPromptButton
            }
            .padding(8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onTapGesture {
            focusedField = nil
        }
    }

    // MARK: - Column Footer

    @ViewBuilder
    private var columnFooter: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { !hideCompleted },
                set: { store.hideCompleted = !$0 }
            )) {
                Text("Show Completed")
                    .font(PreferencesManager.uiFont(size: 11))
                    .foregroundColor(.secondary)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Spacer()

            // Board navigation
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.activeBoardIndex = max(0, store.activeBoardIndex - 1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(store.activeBoardIndex <= 0)

            Text("\(store.activeBoardIndex + 1)/\(store.boards.count)")
                .font(PreferencesManager.uiFont(size: 11))
                .foregroundColor(.secondary)
                .monospacedDigit()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.activeBoardIndex = min(store.boards.count - 1, store.activeBoardIndex + 1)
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(store.activeBoardIndex >= store.boards.count - 1)

            // New board button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    _ = store.addBoard()
                    store.activeBoardIndex = store.boards.count - 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(HoverButtonStyle())
            .help("New board")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

import SwiftUI
import AppKit

// MARK: - Status Helpers

extension View {
    @ViewBuilder
    func applyStatus(_ status: ItemStatus) -> some View {
        switch status {
        case .default:
            self
        case .inProgress:
            self.italic()
        case .done:
            self.strikethrough().opacity(0.5)
        }
    }
}

private func statusColor(_ status: ItemStatus) -> Color {
    switch status {
    case .default: return .secondary
    case .inProgress: return .orange
    case .done: return .green
    }
}

private func statusIcon(_ status: ItemStatus) -> String {
    switch status {
    case .default: return "circle"
    case .inProgress: return "circle.dotted.circle"
    case .done: return "checkmark.circle.fill"
    }
}

// MARK: - Focus tracking

enum BacklogField: Hashable {
    case badgeTitle(UUID)
    case bulletText(UUID)
}

// MARK: - Backlog Divider

struct BacklogDividerView: View {
    @Bindable var windowState: WindowState
    let totalWidth: CGFloat

    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isDragging || isHovering ? Color.accentColor : Color.gray.opacity(0.3))
            .frame(width: isDragging ? 4 : 2)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let delta = -value.translation.width / totalWidth
                        let newRatio = windowState.backlogWidthRatio + delta
                        windowState.backlogWidthRatio = min(max(newRatio, 0.15), 0.50)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

// MARK: - Bullet Row

struct BulletRowView: View {
    @Bindable var bullet: Bullet
    let onDelete: () -> Void
    var focusedField: FocusState<BacklogField?>.Binding
    private let prefs = PreferencesManager.shared

    private var isEditing: Bool {
        focusedField.wrappedValue == .bulletText(bullet.id)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Status icon — tap to cycle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    bullet.status = bullet.status.next
                }
            }) {
                Image(systemName: statusIcon(bullet.status))
                    .font(prefs.backlogFont)
                    .foregroundColor(statusColor(bullet.status))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(HoverButtonStyle())

            // Always a TextField — styled differently based on focus
            TextField("Enter prompt...", text: $bullet.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(prefs.backlogFont)
                .lineLimit(nil)
                .padding(.horizontal, isEditing ? 4 : 0)
                .padding(.vertical, isEditing ? 2 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isEditing ? Color.accentColor : Color.clear, lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isEditing ? Color(nsColor: .textBackgroundColor) : Color.clear)
                        )
                )
                .applyStatus(isEditing ? .default : bullet.status)
                .focused(focusedField, equals: .bulletText(bullet.id))
                .onSubmit {
                    focusedField.wrappedValue = nil
                }
                .onChange(of: isEditing) { _, editing in
                    if !editing && bullet.text.trimmingCharacters(in: .whitespaces).isEmpty {
                        bullet.text = "New prompt"
                    }
                }

            // Copy button
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(bullet.text, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: prefs.backlogFontSize - 2))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(HoverButtonStyle())
            .visibleOnRowHover()
            .help("Copy bullet text")
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
        .hoverReveal()
        .contextMenu {
            Button("Delete Bullet", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Badge Card

struct BadgeCardView: View {
    @Bindable var badge: Badge
    var hideCompleted: Bool = false
    let onDelete: () -> Void
    var focusedField: FocusState<BacklogField?>.Binding
    private let prefs = PreferencesManager.shared

    @State private var draggedBullet: Bullet?
    @State private var isCardHovered = false

    private var isEditingTitle: Bool {
        focusedField.wrappedValue == .badgeTitle(badge.id)
    }

    private var visibleBullets: [Bullet] {
        if !hideCompleted { return badge.bullets }
        return badge.bullets.filter { !$0.isHideable }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            HStack(spacing: 6) {
                // Status dot — tap to cycle (cascades to bullets)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        badge.cycleStatus()
                    }
                }) {
                    Circle()
                        .fill(statusColor(badge.status))
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(HoverButtonStyle(padding: 6))

                // Always a TextField — styled differently based on focus
                TextField("Enter group name...", text: $badge.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(prefs.backlogTitleFont)
                    .lineLimit(nil)
                    .padding(.horizontal, isEditingTitle ? 4 : 0)
                    .padding(.vertical, isEditingTitle ? 2 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isEditingTitle ? Color.accentColor : Color.clear, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isEditingTitle ? Color(nsColor: .textBackgroundColor) : Color.clear)
                            )
                    )
                    .applyStatus(isEditingTitle ? .default : badge.status)
                    .focused(focusedField, equals: .badgeTitle(badge.id))
                    .onSubmit {
                        focusedField.wrappedValue = nil
                    }
                    .onChange(of: isEditingTitle) { _, editing in
                        if !editing && badge.title.trimmingCharacters(in: .whitespaces).isEmpty {
                            badge.title = "New Group"
                        }
                    }

                // Copy badge text
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(badge.copyText, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: prefs.backlogFontSize - 2))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .visibleOnRowHover()
                .help("Copy group as text")
            }
            .hoverReveal()

            // Bullets list
            if !visibleBullets.isEmpty {
                ForEach(visibleBullets) { bullet in
                    BulletRowView(
                        bullet: bullet,
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                badge.removeBullet(id: bullet.id)
                            }
                        },
                        focusedField: focusedField
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                    .onDrag {
                        draggedBullet = bullet
                        return NSItemProvider(object: bullet.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: BulletDropDelegate(
                        bullet: bullet,
                        badge: badge,
                        draggedBullet: $draggedBullet
                    ))
                }
            }

            // Add prompt button below bullets
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    let newId = badge.addBullet()
                    focusedField.wrappedValue = .bulletText(newId)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: prefs.backlogFontSize - 2))
                    Text("Add prompt")
                        .font(prefs.backlogFont)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(AddButtonStyle())
            .padding(.leading, 8)
            .padding(.top, 2)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(isCardHovered ? 0.4 : 0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isCardHovered ? 0.08 : 0), radius: 4, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isCardHovered = hovering
            }
        }
        .contextMenu {
            Button("Delete Group", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Panel Mode

enum BacklogPanelMode: String, CaseIterable {
    case backlog = "Backlog"
    case chat = "Chat"
    case github = "GitHub"
}

// MARK: - Backlog Panel

struct BacklogPanelView: View {
    @Bindable var windowState: WindowState
    @State private var draggedBadge: Badge?
    @FocusState private var focusedField: BacklogField?
    @State private var tick = false  // triggers re-evaluation of hideable state
    @State private var panelMode: BacklogPanelMode = .backlog
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var visibleBadges: [Badge] {
        if !windowState.backlog.hideCompleted {
            return windowState.backlog.badges
        }
        return windowState.backlog.badges.filter { !$0.isHideable }
    }

    private var hiddenCount: Int {
        windowState.backlog.badges.count - visibleBadges.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with segmented picker
            HStack {
                Picker("", selection: $panelMode) {
                    ForEach(BacklogPanelMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if panelMode == .backlog {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(windowState.backlog.copyAllText, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Copy all as markdown")
                    .disabled(windowState.backlog.badges.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch panelMode {
            case .chat:
                AIChatView(
                    chatSession: windowState.backlog.chatSession,
                    backlogContext: windowState.backlog.copyAllText
                )
            case .github:
                GitHubPanelView(githubState: windowState.githubState)
            case .backlog:
                backlogContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(timer) { _ in
            // Periodically re-evaluate so items hide after 15s grace period
            if windowState.backlog.hideCompleted {
                tick.toggle()
            }
        }
        // Force view re-evaluation when tick changes
        .id(tick)
    }

    @ViewBuilder
    private var backlogContent: some View {
            // Badge list
            if windowState.backlog.badges.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No groups yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            let newId = windowState.backlog.addBadge()
                            focusedField = .badgeTitle(newId)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11))
                            Text("Add group")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(AddButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleBadges) { badge in
                            BadgeCardView(
                                badge: badge,
                                hideCompleted: windowState.backlog.hideCompleted,
                                onDelete: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        windowState.backlog.removeBadge(id: badge.id)
                                    }
                                },
                                focusedField: $focusedField
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                            .onDrag {
                                draggedBadge = badge
                                return NSItemProvider(object: badge.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: BadgeDropDelegate(
                                badge: badge,
                                store: windowState.backlog,
                                draggedBadge: $draggedBadge
                            ))
                        }

                        // Add group button below all badges
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                let newId = windowState.backlog.addBadge()
                                focusedField = .badgeTitle(newId)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11))
                                Text("Add group")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(AddButtonStyle())
                    }
                    .padding(8)
                }
            }

            Divider()

            // Footer — hide completed toggle
            HStack {
                Toggle(isOn: $windowState.backlog.hideCompleted) {
                    Text("Hide completed")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)

                if windowState.backlog.hideCompleted && hiddenCount > 0 {
                    Text("(\(hiddenCount) hidden)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}

// MARK: - Drop Delegates

struct BadgeDropDelegate: DropDelegate {
    let badge: Badge
    let store: BacklogStore
    @Binding var draggedBadge: Badge?

    func performDrop(info: DropInfo) -> Bool {
        draggedBadge = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedBadge,
              dragged.id != badge.id,
              let fromIndex = store.badges.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = store.badges.firstIndex(where: { $0.id == badge.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            store.moveBadge(fromIndex: fromIndex, toIndex: toIndex)
        }
    }
}

struct BulletDropDelegate: DropDelegate {
    let bullet: Bullet
    let badge: Badge
    @Binding var draggedBullet: Bullet?

    func performDrop(info: DropInfo) -> Bool {
        draggedBullet = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedBullet,
              dragged.id != bullet.id,
              let fromIndex = badge.bullets.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = badge.bullets.firstIndex(where: { $0.id == bullet.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            badge.moveBullet(fromIndex: fromIndex, toIndex: toIndex)
        }
    }
}

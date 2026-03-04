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

func statusColor(_ status: ItemStatus) -> Color {
    switch status {
    case .default: return .secondary
    case .inProgress: return .orange
    case .done: return .green
    }
}

func statusIcon(_ status: ItemStatus) -> String {
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
    let board: KanbanBoard
    let onDelete: () -> Void
    var onSave: () -> Void
    var focusedField: FocusState<BacklogField?>.Binding
    private let prefs = PreferencesManager.shared

    private var isEditing: Bool {
        focusedField.wrappedValue == .bulletText(bullet.id)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
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
                    if bullet.text.trimmingCharacters(in: .whitespaces).isEmpty {
                        withAnimation(.easeInOut(duration: 0.25)) { onDelete() }
                    } else {
                        onSave()
                        if let idx = board.bullets.firstIndex(where: { $0.id == bullet.id }) {
                            let newBullet = Bullet()
                            board.bullets.insert(newBullet, at: idx + 1)
                            focusedField.wrappedValue = .bulletText(newBullet.id)
                        }
                    }
                }
                .onChange(of: isEditing) { _, editing in
                    if !editing && bullet.text.trimmingCharacters(in: .whitespaces).isEmpty {
                        withAnimation(.easeInOut(duration: 0.25)) { onDelete() }
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
        .padding(.vertical, 1)
        .padding(.leading, 6)
        .hoverReveal()
        .contextMenu {
            Button("Delete Bullet", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Drop Delegates

struct BoardBulletDropDelegate: DropDelegate {
    let bullet: Bullet
    let board: KanbanBoard
    @Binding var draggedBullet: Bullet?

    func performDrop(info: DropInfo) -> Bool {
        draggedBullet = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedBullet,
              dragged.id != bullet.id,
              let fromIndex = board.bullets.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = board.bullets.firstIndex(where: { $0.id == bullet.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            board.moveBullet(fromIndex: fromIndex, toIndex: toIndex)
        }
    }
}

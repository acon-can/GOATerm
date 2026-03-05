import SwiftUI

struct TabBarView: View {
    @Bindable var windowState: WindowState
    @State private var editingTabId: UUID?
    @State private var draggedTab: TabModel?

    // NOTE: The island height, padding, and traffic-light spacer width are
    // mirrored in IslandLayout (MainWindowView.swift) for traffic-light
    // positioning. If you change these values, update IslandLayout too.

    var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer — width covers 3 buttons at IslandLayout spacing
            Color.clear
                .frame(width: IslandLayout.trafficLightX + CGFloat(2) * IslandLayout.trafficLightSpacing + 14)
                .allowsHitTesting(false)

            // Tab scroll area
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(windowState.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == windowState.activeTabId,
                            isEditing: editingTabId == tab.id,
                            onSelect: {
                                windowState.activeTabId = tab.id
                                for session in tab.allSessions {
                                    session.hasUnseenCompletion = false
                                }
                            },
                            onStartEditing: { editingTabId = tab.id },
                            onEndEditing: { editingTabId = nil },
                            onClose: { windowState.closeTab(id: tab.id) },
                            onDuplicate: { windowState.duplicateTab(id: tab.id) },
                            onCloseOthers: { windowState.closeOtherTabs(keepingId: tab.id) },
                            onSetColor: { color in
                                tab.focusedSession?.color = color
                            },
                            canClose: windowState.tabs.count > 1
                        )
                        .onDrag {
                            draggedTab = tab
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            tab: tab,
                            windowState: windowState,
                            draggedTab: $draggedTab
                        ))
                    }

                    // New tab button
                    Button(action: { windowState.addTab() }) {
                        Image(systemName: "plus")
                            .font(PreferencesManager.uiFont(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(HoverButtonStyle(cornerRadius: 6))
                    .help("New Tab (Cmd+T)")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }

            // Backlog toggle button — right-aligned inside the island
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    windowState.toggleBacklog()
                }
            }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 12))
                    .foregroundColor(windowState.isBacklogVisible ? .accentColor : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(HoverButtonStyle(cornerRadius: 6))
            .help("Toggle Backlog (Cmd+Shift+B)")
            .padding(.trailing, 6)
        }
        .frame(height: IslandLayout.height)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
        .padding(.top, IslandLayout.outerPadding)
        .padding(.leading, IslandLayout.outerPadding)
        .padding(.bottom, IslandLayout.outerPadding)
    }
}

struct TabItemView: View {
    @Bindable var tab: TabModel
    let isActive: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void
    let onClose: () -> Void
    let onDuplicate: () -> Void
    let onCloseOthers: () -> Void
    let onSetColor: (TerminalColor) -> Void
    let canClose: Bool

    @State private var editName: String = ""
    @State private var isTabHovered = false
    @State private var showGitGraph = false

    private var tabBackground: Color {
        if tab.color != .default {
            return tab.color.swiftUIColor.opacity(isActive ? 0.2 : 0.1)
        }
        if isActive {
            return Color.accentColor.opacity(0.15)
        }
        return isTabHovered ? Color.primary.opacity(0.06) : Color.clear
    }

    private var tabBorderColor: Color {
        if tab.color != .default {
            return tab.color.swiftUIColor.opacity(isActive ? 0.4 : 0.2)
        }
        return isActive ? Color.accentColor.opacity(0.3) : Color.clear
    }

    var body: some View {
        HStack(spacing: 6) {
            // Color dot
            Circle()
                .fill(tab.color.swiftUIColor)
                .frame(width: 8, height: 8)

            // Tab name
            if isEditing {
                TextField("Name", text: $editName, onCommit: {
                    tab.focusedSession?.name = editName
                    onEndEditing()
                })
                .textFieldStyle(.plain)
                .font(PreferencesManager.uiFont(size: 12))
                .frame(width: 100)
                .onAppear { editName = tab.focusedSession?.name ?? "Terminal" }
            } else {
                Text(tab.displayTitle)
                    .font(PreferencesManager.uiFont(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // Status indicators
            if tab.allSessions.contains(where: { $0.hasUnseenCompletion }) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .pulsing()
            }

            if let session = tab.focusedSession {
                if let branch = session.gitBranch {
                    Button(action: { showGitGraph.toggle() }) {
                        Text(branch)
                            .font(PreferencesManager.uiFont(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showGitGraph) {
                        GitGraphView(directory: session.currentDirectory)
                    }
                }
            }

            // Close button
            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle(cornerRadius: 4, padding: 3))
                .opacity(isActive ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tabBackground)
        .animation(.easeInOut(duration: 0.15), value: isTabHovered)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tabBorderColor, lineWidth: 1)
        )
        .onHover { hovering in
            isTabHovered = hovering
        }
        .onTapGesture(count: 2) {
            onStartEditing()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .contextMenu {
            Button("Rename...") { onStartEditing() }
            Menu("Set Color") {
                ForEach(TerminalColor.allCases, id: \.rawValue) { color in
                    Button(action: { onSetColor(color) }) {
                        HStack {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 10, height: 10)
                            Text(color.rawValue.capitalized)
                        }
                    }
                }
            }
            Divider()
            Button("Duplicate Tab") { onDuplicate() }
            Divider()
            Button("Close Tab") { onClose() }
                .disabled(!canClose)
            Button("Close Other Tabs") { onCloseOthers() }
                .disabled(!canClose)
        }
    }
}

struct TabDropDelegate: DropDelegate {
    let tab: TabModel
    let windowState: WindowState
    @Binding var draggedTab: TabModel?

    func performDrop(info: DropInfo) -> Bool {
        draggedTab = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedTab,
              dragged.id != tab.id,
              let fromIndex = windowState.tabs.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = windowState.tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            windowState.moveTab(fromIndex: fromIndex, toIndex: toIndex)
        }
    }
}

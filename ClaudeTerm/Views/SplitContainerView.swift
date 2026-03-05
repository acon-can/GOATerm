import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SplitContainerView: View {
    let paneNode: PaneNode
    let focusedSessionId: UUID?
    var onFocusSession: ((UUID) -> Void)?
    var onProcessExit: ((UUID) -> Void)?

    private var prefs: PreferencesManager { PreferencesManager.shared }

    var body: some View {
        switch paneNode {
        case .terminal(let session):
            VStack(spacing: 0) {
                TerminalPaneView(
                    session: session,
                    isFocused: session.id == focusedSessionId,
                    fontName: PreferencesManager.defaultFontName,
                    fontSize: prefs.fontSize,
                    onProcessExit: { onProcessExit?(session.id) }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onFocusSession?(session.id)
                }
                .overlay {
                    TerminalDropOverlay(sessionId: session.id)
                }
                .overlay(alignment: .center) {
                    if !session.isRunning {
                        processTerminatedOverlay(session: session)
                    }
                }

                TerminalStatusBarView(session: session)
            }
            .overlay(alignment: .bottom) {
                SudoBypassOverlay(session: session) {
                    TerminalPaneView.Coordinator.coordinators[session.id]?.sendText("sudo !!\n")
                }
            }

        case .split(let orientation, let first, let second, let ratio):
            GeometryReader { geometry in
                if orientation == .horizontal {
                    HStack(spacing: 1) {
                        SplitContainerView(
                            paneNode: first,
                            focusedSessionId: focusedSessionId,
                            onFocusSession: onFocusSession,
                            onProcessExit: onProcessExit
                        )
                        .frame(width: geometry.size.width * ratio - 0.5)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1)

                        SplitContainerView(
                            paneNode: second,
                            focusedSessionId: focusedSessionId,
                            onFocusSession: onFocusSession,
                            onProcessExit: onProcessExit
                        )
                    }
                } else {
                    VStack(spacing: 1) {
                        SplitContainerView(
                            paneNode: first,
                            focusedSessionId: focusedSessionId,
                            onFocusSession: onFocusSession,
                            onProcessExit: onProcessExit
                        )
                        .frame(height: geometry.size.height * ratio - 0.5)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)

                        SplitContainerView(
                            paneNode: second,
                            focusedSessionId: focusedSessionId,
                            onFocusSession: onFocusSession,
                            onProcessExit: onProcessExit
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func processTerminatedOverlay(session: TerminalSession) -> some View {
        VStack(spacing: 12) {
            Text("Process terminated")
                .font(.headline)
                .foregroundColor(.white)
            if let code = session.lastExitCode {
                Text("Exit code: \(code)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button("Restart") {
                session.isRunning = true
                // The view will be recreated
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Terminal Drop Overlay

/// NSViewRepresentable overlay for accepting file drops on the terminal.
/// The underlying NSView returns nil from hitTest so mouse/keyboard events pass
/// through to the terminal. AppKit dispatches drag-and-drop separately from
/// hitTest, so registered drag types still work.
struct TerminalDropOverlay: NSViewRepresentable {
    let sessionId: UUID

    func makeNSView(context: Context) -> DropOverlayNSView {
        let view = DropOverlayNSView()
        view.sessionId = sessionId
        view.registerForDraggedTypes([.fileURL])
        return view
    }

    func updateNSView(_ nsView: DropOverlayNSView, context: Context) {
        nsView.sessionId = sessionId
    }
}

class DropOverlayNSView: NSView {
    var sessionId: UUID?
    private var isDragActive = false

    // Return nil so all mouse/keyboard events pass to the terminal below.
    // Drag-and-drop uses a separate dispatch mechanism and is not affected.
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFileURLs(sender) else { return [] }
        isDragActive = true
        needsDisplay = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFileURLs(sender) else { return [] }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragActive = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragActive = false
        needsDisplay = true

        guard let sessionId = sessionId,
              let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
                  .urlReadingFileURLsOnly: true
              ]) as? [URL],
              !items.isEmpty else {
            return false
        }

        let paths = items.map { url in
            url.path.contains(" ") ? "\"\(url.path)\"" : url.path
        }
        TerminalPaneView.Coordinator.coordinators[sessionId]?.sendText(paths.joined(separator: " "))
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isDragActive = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isDragActive {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            let rect = bounds.insetBy(dx: 4, dy: 4)
            let bgPath = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
            bgPath.fill()

            NSColor.controlAccentColor.withAlphaComponent(0.5).setStroke()
            let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
            border.lineWidth = 2
            let dashPattern: [CGFloat] = [6, 4]
            border.setLineDash(dashPattern, count: 2, phase: 0)
            border.stroke()
        }
    }

    private func hasFileURLs(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return false
        }
        return !items.isEmpty
    }
}

import SwiftUI

struct SplitContainerView: View {
    let paneNode: PaneNode
    let focusedSessionId: UUID?
    var onFocusSession: ((UUID) -> Void)?
    var onProcessExit: ((UUID) -> Void)?

    var body: some View {
        switch paneNode {
        case .terminal(let session):
            VStack(spacing: 0) {
                TerminalPaneView(
                    session: session,
                    isFocused: session.id == focusedSessionId,
                    onProcessExit: { onProcessExit?(session.id) }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(
                            session.id == focusedSessionId ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onFocusSession?(session.id)
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

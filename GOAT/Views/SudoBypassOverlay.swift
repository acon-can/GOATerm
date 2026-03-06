import SwiftUI

struct SudoBypassOverlay: View {
    let session: TerminalSession
    let onSudo: () -> Void

    var body: some View {
        if session.showSudoSuggestion {
            Button(action: onSudo) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11))
                    Text("Re-run with sudo")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: session.showSudoSuggestion)
        }
    }
}

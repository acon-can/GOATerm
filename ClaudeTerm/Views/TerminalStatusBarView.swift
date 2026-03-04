import SwiftUI

struct TerminalStatusBarView: View {
    let session: TerminalSession
    @State private var showHistory = false

    private var abbreviatedDirectory: String {
        let home = NSHomeDirectory()
        let dir = session.currentDirectory
        if dir == home {
            return "~"
        } else if dir.hasPrefix(home + "/") {
            return "~/" + String(dir.dropFirst(home.count + 1))
        }
        return dir
    }

    private var isClaudeCodeRunning: Bool {
        guard let cmd = session.runningCommand else { return false }
        let lower = cmd.lowercased()
        return lower.hasPrefix("claude")
    }

    /// Extract the prompt portion from a claude command (everything after "claude ")
    private var lastClaudePrompt: String? {
        guard let cmd = session.lastCommand else { return nil }
        let lower = cmd.lowercased()
        guard lower.hasPrefix("claude") else { return nil }
        // Strip the "claude" prefix and any leading whitespace
        let afterClaude = cmd.dropFirst("claude".count).drop(while: { $0 == " " })
        let prompt = String(afterClaude)
        return prompt.isEmpty ? nil : prompt
    }

    private var truncatedPrompt: String? {
        guard let prompt = lastClaudePrompt else { return nil }
        if prompt.count <= 40 {
            return prompt
        }
        return String(prompt.prefix(40)) + "..."
    }

    var body: some View {
        HStack(spacing: 6) {
            if isClaudeCodeRunning, let display = truncatedPrompt {
                Button(action: { showHistory = true }) {
                    Text(display)
                        .lineLimit(1)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(HoverButtonStyle(padding: 2))
                .help("View prompt history")
            }

            Spacer()
            Text(abbreviatedDirectory)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.secondary)
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showHistory) {
            PromptHistoryView(directory: session.currentDirectory)
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

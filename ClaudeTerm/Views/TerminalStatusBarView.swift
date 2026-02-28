import SwiftUI

struct TerminalStatusBarView: View {
    let session: TerminalSession

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

    var body: some View {
        HStack {
            if let cmd = session.lastCommand {
                Text(cmd)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
    }
}

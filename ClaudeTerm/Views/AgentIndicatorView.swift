import SwiftUI

struct ServerIndicatorView: View {
    let serverStore: ServerStore

    private var runningCount: Int {
        serverStore.servers.filter { $0.status == .running }.count
    }

    private var hasErrors: Bool {
        serverStore.servers.contains { $0.status == .error || $0.status == .crashed }
    }

    var body: some View {
        if !serverStore.servers.isEmpty {
            HStack(spacing: 4) {
                Circle()
                    .fill(hasErrors ? Color.orange : (runningCount > 0 ? Color.green : Color.gray))
                    .frame(width: 6, height: 6)
                Text("\(runningCount)/\(serverStore.servers.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1), in: Capsule())
        }
    }
}

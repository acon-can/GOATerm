import SwiftUI

struct AgentIndicatorView: View {
    let agentStore: AgentStore

    private var runningCount: Int {
        agentStore.agents.filter { $0.status == .running }.count
    }

    private var hasErrors: Bool {
        agentStore.agents.contains { $0.status == .error || $0.status == .crashed }
    }

    var body: some View {
        if !agentStore.agents.isEmpty {
            HStack(spacing: 4) {
                Circle()
                    .fill(hasErrors ? Color.orange : (runningCount > 0 ? Color.green : Color.gray))
                    .frame(width: 6, height: 6)
                Text("\(runningCount)/\(agentStore.agents.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1), in: Capsule())
        }
    }
}

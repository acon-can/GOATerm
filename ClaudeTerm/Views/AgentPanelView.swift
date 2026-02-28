import SwiftUI

struct AgentPanelView: View {
    @Bindable var agentStore: AgentStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dev Agents")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { agentStore.addAgent() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            if agentStore.agents.isEmpty {
                VStack(spacing: 8) {
                    Text("No agents configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Add Agent") { agentStore.addAgent() }
                        .buttonStyle(AddButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(agentStore.agents) { agent in
                            AgentCardView(agent: agent, onRemove: {
                                agentStore.removeAgent(id: agent.id)
                            })
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct AgentCardView: View {
    @Bindable var agent: AgentSession
    let onRemove: () -> Void
    @State private var showLogs = false

    private var statusColor: Color {
        switch agent.status {
        case .stopped: return .gray
        case .starting: return .yellow
        case .running: return .green
        case .error: return .red
        case .crashed: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                if agent.name.isEmpty {
                    TextField("Name", text: $agent.name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 80)
                } else {
                    Text(agent.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }

                if let port = agent.detectedPort {
                    Text(":\(port)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            TextField("Command (e.g. npm run dev)", text: $agent.command)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .frame(width: 180)

            HStack(spacing: 4) {
                if agent.status == .stopped || agent.status == .error {
                    Button("Start") {
                        DevServerService.shared.start(agent: agent, directory: NSHomeDirectory())
                    }
                    .controlSize(.small)
                    .disabled(agent.command.isEmpty)
                } else {
                    Button("Stop") {
                        agent.status = .stopped
                        DevServerService.shared.stop(agentId: agent.id)
                    }
                    .controlSize(.small)

                    Button("Restart") {
                        DevServerService.shared.restart(agent: agent, directory: NSHomeDirectory())
                    }
                    .controlSize(.small)
                }

                Spacer()

                Button(action: { showLogs.toggle() }) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 10))
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
            }

            if showLogs {
                ScrollView {
                    Text(agent.logOutput.isEmpty ? "(no output)" : agent.logOutput)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

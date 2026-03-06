import SwiftUI

struct ClaudeProjectView: View {
    let directory: String
    @State private var config = ClaudeProjectConfig()
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Claude Project")
                    .font(.headline)
                Spacer()
                if config.isLoaded {
                    Text(config.projectRoot)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .padding()

            Divider()

            if !config.isLoaded {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No .claude/ directory found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $selectedTab) {
                    instructionsTab
                        .tabItem { Label("Instructions", systemImage: "doc.text") }
                        .tag(0)

                    settingsTab
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(1)

                    mcpTab
                        .tabItem { Label("MCP Servers", systemImage: "server.rack") }
                        .tag(2)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 450)
        .task {
            config = ClaudeProjectService.load(from: directory)
        }
    }

    @ViewBuilder
    private var instructionsTab: some View {
        if config.claudeMD.isEmpty {
            Text("No CLAUDE.md found")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                Text(config.claudeMD)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var settingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !config.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Skills")
                            .font(.headline)
                        ForEach(config.skills, id: \.self) { skill in
                            Text("- \(skill)")
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                }

                if !config.settingsJSON.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw Settings")
                            .font(.headline)
                        Text(config.settingsJSON)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var mcpTab: some View {
        if config.mcpServers.isEmpty {
            Text("No MCP servers configured")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(Array(config.mcpServers.values)) { server in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.headline)
                        Text("\(server.command) \(server.args.joined(separator: " "))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

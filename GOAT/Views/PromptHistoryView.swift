import SwiftUI
import AppKit

struct PromptHistoryView: View {
    let directory: String
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [PromptEntry] = []
    @State private var refreshTimer: Timer?

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d, HH:mm"
        return df
    }()

    @State private var showInfoPopover = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat History")
                    .font(.system(size: 13, weight: .semibold))

                Button(action: { showInfoPopover.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Sources")
                            .font(.system(size: 11, weight: .semibold))

                        HStack(spacing: 6) {
                            Text("Chat")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                            Text("Prompts sent from the Chat panel, saved in chat-history.goat.md")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            Text("Claude Code")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                            Text("Prompts from Claude Code sessions in ~/.claude/projects/")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        Text("No additional logging is performed. All data is read from existing files on disk.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(width: 320)
                }

                Spacer()

                Button(action: {
                    let text = PromptHistoryService.shared.copyAllText(directory: directory)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Copy All")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
                .disabled(entries.isEmpty)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No prompts recorded yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(entries) { entry in
                            PromptRowView(entry: entry, dateFormatter: dateFormatter)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 480, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            entries = PromptHistoryService.shared.loadAllHistory(directory: directory)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                DispatchQueue.main.async {
                    entries = PromptHistoryService.shared.loadAllHistory(directory: directory)
                }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
}

struct PromptRowView: View {
    let entry: PromptEntry
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.prompt)
                    .font(.system(size: 12))
                    .lineLimit(nil)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(entry.source == .chat ? "Chat" : "Claude Code")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(entry.source == .chat ? .blue : .orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(entry.source == .chat ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                        )

                    Text(dateFormatter.string(from: entry.timestamp))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.prompt, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(HoverButtonStyle())
            .help("Copy prompt")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .hoverReveal()
    }
}

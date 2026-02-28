import SwiftUI

struct GitGraphView: View {
    let directory: String
    @State private var logOutput: String = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Git Graph")
                    .font(.headline)
                Spacer()
                Button(action: { Task { await refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(HoverButtonStyle())
                .disabled(isLoading)
            }
            .padding(12)

            Divider()

            if isLoading && logOutput.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if logOutput.isEmpty {
                Text("No git history found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(logOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
        }
        .frame(width: 500, height: 400)
        .task { await refresh() }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            logOutput = try await GitService.fetchLog(in: directory)
        } catch {
            logOutput = "Error: \(error.localizedDescription)"
        }
    }
}

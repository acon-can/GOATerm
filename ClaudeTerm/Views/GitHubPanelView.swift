import SwiftUI

struct GitHubPanelView: View {
    @Bindable var githubState: GitHubState

    var body: some View {
        if !githubState.isAuthenticated {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("GitHub CLI not authenticated")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Run `gh auth login` in terminal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !githubState.myPRs.isEmpty {
                        sectionHeader("My Pull Requests", count: githubState.myPRs.count)
                        ForEach(githubState.myPRs) { pr in
                            PRRowView(pr: pr, showActions: false)
                        }
                    }

                    if !githubState.reviewRequests.isEmpty {
                        sectionHeader("Review Requests", count: githubState.reviewRequests.count)
                        ForEach(githubState.reviewRequests) { pr in
                            PRRowView(pr: pr, showActions: true)
                        }
                    }

                    if !githubState.assignedIssues.isEmpty {
                        sectionHeader("My Issues", count: githubState.assignedIssues.count)
                        ForEach(githubState.assignedIssues) { issue in
                            IssueRowView(issue: issue)
                        }
                    }

                    if githubState.myPRs.isEmpty && githubState.reviewRequests.isEmpty && githubState.assignedIssues.isEmpty {
                        if githubState.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Text("No items found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 20)
                        }
                    }

                    if let error = githubState.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(8)
            }
            .task {
                await GitHubPollingService.shared.refresh(state: githubState)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .background(Color.secondary.opacity(0.15), in: Capsule())
            Spacer()
        }
        .padding(.top, 4)
    }
}

struct PRRowView: View {
    let pr: PRInfo
    let showActions: Bool

    private var ciColor: Color {
        switch pr.ciStatus?.displayState ?? .unknown {
        case .success: return .green
        case .failure: return .red
        case .pending: return .yellow
        case .unknown: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(ciColor)
                    .frame(width: 6, height: 6)
                Text("#\(pr.number)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(pr.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(pr.headRefName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1), in: Capsule())

                if showActions {
                    Spacer()
                    Button("Approve") {
                        Task { try? await GitHubService.approvePR(number: pr.number) }
                    }
                    .controlSize(.mini)

                    Button("Merge") {
                        Task { try? await GitHubService.mergePR(number: pr.number) }
                    }
                    .controlSize(.mini)
                }
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct IssueRowView: View {
    let issue: GitHubIssue

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: issue.state == "OPEN" ? "circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(issue.state == "OPEN" ? .green : .purple)
            Text("#\(issue.number)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            Text(issue.title)
                .font(.system(size: 12))
                .lineLimit(1)
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

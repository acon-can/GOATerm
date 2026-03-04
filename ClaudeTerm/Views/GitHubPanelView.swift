import SwiftUI

struct GitHubPanelView: View {
    @Bindable var githubState: GitHubState
    var currentDirectory: String?

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
                    // Repo badge
                    if let repo = githubState.currentRepo {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 10))
                            Text(repo)
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }

                    // Local git status
                    if let info = githubState.localGitInfo {
                        localGitSection(info)
                    }

                    // GitHub PRs
                    if !githubState.filteredPRs.isEmpty {
                        sectionHeader("My Pull Requests", count: githubState.filteredPRs.count)
                        ForEach(githubState.filteredPRs) { pr in
                            PRRowView(pr: pr, showActions: false)
                        }
                    }

                    // Review requests
                    if !githubState.filteredReviewRequests.isEmpty {
                        sectionHeader("Review Requests", count: githubState.filteredReviewRequests.count)
                        ForEach(githubState.filteredReviewRequests) { pr in
                            PRRowView(pr: pr, showActions: true)
                        }
                    }

                    // Assigned issues
                    if !githubState.filteredIssues.isEmpty {
                        sectionHeader("My Issues", count: githubState.filteredIssues.count)
                        ForEach(githubState.filteredIssues) { issue in
                            IssueRowView(issue: issue)
                        }
                    }

                    if githubState.localGitInfo == nil && githubState.filteredPRs.isEmpty && githubState.filteredReviewRequests.isEmpty && githubState.filteredIssues.isEmpty {
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
                await detectRepoAndGitInfo()
            }
            .onChange(of: currentDirectory) { _, _ in
                Task { await detectRepoAndGitInfo() }
            }
        }
    }

    // MARK: - Local Git Info Section

    @ViewBuilder
    private func localGitSection(_ info: LocalGitInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Repository Status", count: 0, showCount: false)

            // Branch + tracking
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text(info.branch)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))

                if let tracking = info.trackingBranch {
                    Text("\u{2192} \(tracking)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            // Ahead/behind
            if info.ahead > 0 || info.behind > 0 {
                HStack(spacing: 8) {
                    if info.ahead > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9))
                            Text("\(info.ahead) ahead")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.green)
                    }
                    if info.behind > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                            Text("\(info.behind) behind")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            // Working tree status
            if info.hasUncommittedChanges {
                HStack(spacing: 8) {
                    if info.stagedCount > 0 {
                        statusBadge(
                            icon: "checkmark.circle.fill",
                            text: "\(info.stagedCount) staged",
                            color: .green
                        )
                    }
                    if info.modifiedCount > 0 {
                        statusBadge(
                            icon: "pencil.circle.fill",
                            text: "\(info.modifiedCount) modified",
                            color: .orange
                        )
                    }
                    if info.untrackedCount > 0 {
                        statusBadge(
                            icon: "questionmark.circle.fill",
                            text: "\(info.untrackedCount) untracked",
                            color: .secondary
                        )
                    }
                    if info.conflictCount > 0 {
                        statusBadge(
                            icon: "exclamationmark.triangle.fill",
                            text: "\(info.conflictCount) conflicts",
                            color: .red
                        )
                    }
                }
            } else if info.trackingBranch != nil && info.ahead == 0 && info.behind == 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10))
                    Text("Clean, up to date")
                        .font(.system(size: 10))
                }
                .foregroundColor(.green)
            }

            // Stashes
            if info.stashCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 10))
                    Text("\(info.stashCount) stash\(info.stashCount == 1 ? "" : "es")")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            }

            // Recent commits
            if !info.recentCommits.isEmpty {
                sectionHeader("Recent Commits", count: info.recentCommits.count)
                ForEach(info.recentCommits) { commit in
                    commitRow(commit)
                }
            }
        }
    }

    @ViewBuilder
    private func statusBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundColor(color)
    }

    @ViewBuilder
    private func commitRow(_ commit: GitCommitInfo) -> some View {
        HStack(spacing: 6) {
            Text(commit.hash)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.accentColor)
            Text(commit.message)
                .font(PreferencesManager.uiFont(size: 11))
                .lineLimit(1)
            Spacer()
            Text(commit.relativeDate)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Helpers

    private func detectRepoAndGitInfo() async {
        guard let dir = currentDirectory else {
            githubState.currentRepo = nil
            githubState.localGitInfo = nil
            return
        }
        async let repo = GitHubService.detectRepo(in: dir)
        async let gitInfo = GitHubService.fetchLocalGitInfo(in: dir)
        githubState.currentRepo = await repo
        githubState.localGitInfo = await gitInfo
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int, showCount: Bool = true) -> some View {
        HStack {
            Text(title)
                .font(PreferencesManager.uiFont(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            if showCount {
                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            Spacer()
        }
        .padding(.top, 4)
    }
}

struct PRRowView: View {
    let pr: PRInfo
    let showActions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("#\(pr.number)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(pr.title)
                    .font(PreferencesManager.uiFont(size: 12))
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(pr.repoName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1), in: Capsule())

                if showActions {
                    Spacer()
                    Button("Approve") {
                        Task { try? await GitHubService.approvePR(repo: pr.repoName, number: pr.number) }
                    }
                    .controlSize(.mini)

                    Button("Merge") {
                        Task { try? await GitHubService.mergePR(repo: pr.repoName, number: pr.number) }
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
            Image(systemName: issue.state.lowercased() == "open" ? "circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(issue.state.lowercased() == "open" ? .green : .purple)
            Text("#\(issue.number)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            Text(issue.title)
                .font(PreferencesManager.uiFont(size: 12))
                .lineLimit(1)
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

import SwiftUI

enum GitHubSection: String, CaseIterable {
    case repoStatus = "Repo Status"
    case branches = "Branches"
    case recentCommits = "Recent Commits"
    case pullRequests = "Pull Requests"
    case reviewRequests = "Reviews"
    case issues = "Issues"

    var icon: String {
        switch self {
        case .repoStatus: return "arrow.triangle.branch"
        case .branches: return "arrow.triangle.swap"
        case .recentCommits: return "clock"
        case .pullRequests: return "arrow.triangle.pull"
        case .reviewRequests: return "eye"
        case .issues: return "exclamationmark.circle"
        }
    }
}

struct GitHubPanelView: View {
    @Bindable var githubState: GitHubState
    var currentDirectory: String?

    @State private var selectedSection: GitHubSection = .repoStatus

    var body: some View {
        if !githubState.isAuthenticated {
            VStack(alignment: .leading, spacing: 8) {
                Text("Run `gh auth login` in terminal to connect GitHub")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(spacing: 0) {
                HSplitView {
                    // Left sidebar: section list
                    sidebarPanel
                        .frame(minWidth: 140, idealWidth: 160, maxWidth: 200)

                    // Right content: selected section detail
                    ScrollView {
                        detailContent
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom status bar with repo name (mirrors terminal status bar)
                if let repo = githubState.currentRepo {
                    HStack {
                        Spacer()
                        Text(repo)
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
            .background(Color(nsColor: .controlBackgroundColor))
            .task {
                await GitHubPollingService.shared.refresh(state: githubState)
                await detectRepoAndGitInfo()
            }
            .onChange(of: currentDirectory) { _, _ in
                Task { await detectRepoAndGitInfo() }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarPanel: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(GitHubSection.allCases, id: \.self) { section in
                    sidebarRow(section)
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sidebarRow(_ section: GitHubSection) -> some View {
        let isSelected = selectedSection == section
        let count = badgeCount(for: section)

        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 10))
                    .frame(width: 14)
                Text(section.rawValue)
                    .font(PreferencesManager.uiFont(size: 11))
                    .lineLimit(1)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badgeCount(for section: GitHubSection) -> Int {
        switch section {
        case .repoStatus: return 0
        case .branches: return githubState.branches.count
        case .recentCommits: return githubState.localGitInfo?.recentCommits.count ?? 0
        case .pullRequests: return githubState.filteredPRs.count
        case .reviewRequests: return githubState.filteredReviewRequests.count
        case .issues: return githubState.filteredIssues.count
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .repoStatus:
            if let info = githubState.localGitInfo {
                repoStatusContent(info)
            } else if githubState.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No git repository detected")
                    .font(.caption).foregroundColor(.secondary)
            }

        case .branches:
            if !githubState.branches.isEmpty {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(githubState.branches) { branch in
                        branchRow(branch)
                    }
                }
            } else {
                Text("No branches found")
                    .font(.caption).foregroundColor(.secondary)
            }

        case .recentCommits:
            if let info = githubState.localGitInfo, !info.recentCommits.isEmpty {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(info.recentCommits) { commit in
                        commitRow(commit)
                    }
                }
            } else {
                Text("No recent commits")
                    .font(.caption).foregroundColor(.secondary)
            }

        case .pullRequests:
            if !githubState.filteredPRs.isEmpty {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(githubState.filteredPRs) { pr in
                        PRRowView(pr: pr, showActions: false)
                    }
                }
            } else {
                Text("No open pull requests")
                    .font(.caption).foregroundColor(.secondary)
            }

        case .reviewRequests:
            if !githubState.filteredReviewRequests.isEmpty {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(githubState.filteredReviewRequests) { pr in
                        PRRowView(pr: pr, showActions: true)
                    }
                }
            } else {
                Text("No review requests")
                    .font(.caption).foregroundColor(.secondary)
            }

        case .issues:
            if !githubState.filteredIssues.isEmpty {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(githubState.filteredIssues) { issue in
                        IssueRowView(issue: issue)
                    }
                }
            } else {
                Text("No assigned issues")
                    .font(.caption).foregroundColor(.secondary)
            }
        }

        if let error = githubState.lastError {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .padding(.top, 4)
        }
    }

    // MARK: - Repo Status Content

    @ViewBuilder
    private func repoStatusContent(_ info: LocalGitInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        statusBadge(icon: "arrow.up", text: "\(info.ahead) ahead", color: .green)
                    }
                    if info.behind > 0 {
                        statusBadge(icon: "arrow.down", text: "\(info.behind) behind", color: .orange)
                    }
                }
            }

            // Working tree status
            if info.hasUncommittedChanges {
                HStack(spacing: 8) {
                    if info.stagedCount > 0 {
                        statusBadge(icon: "checkmark.circle.fill", text: "\(info.stagedCount) staged", color: .green)
                    }
                    if info.modifiedCount > 0 {
                        statusBadge(icon: "pencil.circle.fill", text: "\(info.modifiedCount) modified", color: .orange)
                    }
                    if info.untrackedCount > 0 {
                        statusBadge(icon: "questionmark.circle.fill", text: "\(info.untrackedCount) untracked", color: .secondary)
                    }
                    if info.conflictCount > 0 {
                        statusBadge(icon: "exclamationmark.triangle.fill", text: "\(info.conflictCount) conflicts", color: .red)
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

    @ViewBuilder
    private func branchRow(_ branch: GitBranchInfo) -> some View {
        HStack(spacing: 6) {
            // Current branch indicator
            Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 9))
                .foregroundColor(branch.isCurrent ? .accentColor : .secondary.opacity(0.4))

            // Branch name
            Text(branch.name)
                .font(.system(size: 11, weight: branch.isCurrent ? .semibold : .regular, design: .monospaced))
                .lineLimit(1)

            Spacer()

            // Ahead/behind badges
            if branch.ahead > 0 {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.up").font(.system(size: 8))
                    Text("\(branch.ahead)").font(.system(size: 9))
                }
                .foregroundColor(.green)
            }
            if branch.behind > 0 {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.down").font(.system(size: 8))
                    Text("\(branch.behind)").font(.system(size: 9))
                }
                .foregroundColor(.orange)
            }

            // Author
            Text(branch.lastAuthor)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(minWidth: 50, alignment: .trailing)

            // Last edited date
            Text(branch.lastCommitDate)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(branch.isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Helpers

    private func detectRepoAndGitInfo() async {
        guard let dir = currentDirectory else {
            githubState.currentRepo = nil
            githubState.localGitInfo = nil
            githubState.branches = []
            return
        }
        async let repo = GitHubService.detectRepo(in: dir)
        async let gitInfo = GitHubService.fetchLocalGitInfo(in: dir)
        async let branchList = GitHubService.fetchBranches(in: dir)
        githubState.currentRepo = await repo
        githubState.localGitInfo = await gitInfo
        githubState.branches = await branchList
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

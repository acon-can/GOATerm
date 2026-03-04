import Foundation

@Observable
final class GitHubState {
    var myPRs: [PRInfo] = []
    var reviewRequests: [PRInfo] = []
    var assignedIssues: [GitHubIssue] = []
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var lastError: String?
    var currentRepo: String?
    var localGitInfo: LocalGitInfo?

    var filteredPRs: [PRInfo] {
        guard let repo = currentRepo else { return myPRs }
        return myPRs.filter { $0.repoName == repo }
    }
    var filteredReviewRequests: [PRInfo] {
        guard let repo = currentRepo else { return reviewRequests }
        return reviewRequests.filter { $0.repoName == repo }
    }
    var filteredIssues: [GitHubIssue] {
        guard let repo = currentRepo else { return assignedIssues }
        return assignedIssues.filter { $0.repoName == repo }
    }
}

struct LocalGitInfo {
    let branch: String
    let trackingBranch: String?
    let ahead: Int
    let behind: Int
    let stagedCount: Int
    let modifiedCount: Int
    let untrackedCount: Int
    let conflictCount: Int
    let stashCount: Int
    let recentCommits: [GitCommitInfo]

    var hasUncommittedChanges: Bool {
        stagedCount + modifiedCount + untrackedCount + conflictCount > 0
    }
}

struct GitCommitInfo: Identifiable {
    let hash: String
    let message: String
    let author: String
    let relativeDate: String
    var id: String { hash }
}

struct SearchRepository: Codable {
    let name: String
    let nameWithOwner: String
}

struct PRInfo: Identifiable, Codable {
    let number: Int
    let title: String
    let state: String
    let url: String
    let repository: SearchRepository?

    var id: String { url }
    var repoName: String { repository?.nameWithOwner ?? "" }
}

struct GitHubIssue: Identifiable, Codable {
    let number: Int
    let title: String
    let state: String
    let url: String
    let repository: SearchRepository?

    var id: String { url }
    var repoName: String { repository?.nameWithOwner ?? "" }
}

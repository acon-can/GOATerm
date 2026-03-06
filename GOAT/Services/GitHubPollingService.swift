import Foundation

final class GitHubPollingService {
    static let shared = GitHubPollingService()
    private var timer: Timer?

    private init() {}

    func startPolling(state: GitHubState) {
        stopPolling()
        // Initial fetch
        Task { await refresh(state: state) }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refresh(state: state) }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh(state: GitHubState) async {
        await MainActor.run { state.isLoading = true }

        do {
            async let prs = GitHubService.fetchMyPRs()
            async let reviews = GitHubService.fetchReviewRequests()
            async let issues = GitHubService.fetchAssignedIssues()

            let (fetchedPRs, fetchedReviews, fetchedIssues) = try await (prs, reviews, issues)

            await MainActor.run {
                state.myPRs = fetchedPRs
                state.reviewRequests = fetchedReviews
                state.assignedIssues = fetchedIssues
                state.isLoading = false
                state.lastError = nil
            }
        } catch {
            await MainActor.run {
                state.isLoading = false
                state.lastError = error.localizedDescription
            }
        }
    }
}

import Foundation

@Observable
final class GitHubState {
    var myPRs: [PRInfo] = []
    var reviewRequests: [PRInfo] = []
    var assignedIssues: [GitHubIssue] = []
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var lastError: String?
}

struct PRInfo: Identifiable, Codable {
    var id: Int { number }
    let number: Int
    let title: String
    let headRefName: String
    let state: String
    let url: String
    let ciStatus: CIStatus?

    enum CodingKeys: String, CodingKey {
        case number, title, headRefName, state, url
        case ciStatus = "statusCheckRollup"
    }
}

struct CIStatus: Codable {
    let state: String?

    var displayState: CIDisplayState {
        switch state?.lowercased() {
        case "success": return .success
        case "failure", "error": return .failure
        case "pending": return .pending
        default: return .unknown
        }
    }
}

enum CIDisplayState {
    case success, failure, pending, unknown

    var colorName: String {
        switch self {
        case .success: return "green"
        case .failure: return "red"
        case .pending: return "yellow"
        case .unknown: return "gray"
        }
    }
}

struct GitHubIssue: Identifiable, Codable {
    var id: Int { number }
    let number: Int
    let title: String
    let state: String
    let url: String
}

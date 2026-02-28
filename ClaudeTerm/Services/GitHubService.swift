import Foundation

enum GitHubService {
    private static var ghPath: String? {
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    static func isAuthenticated() async -> Bool {
        guard let gh = ghPath else { return false }
        let output = try? await run(gh, arguments: ["auth", "status"])
        return output?.contains("Logged in") ?? false
    }

    static func fetchMyPRs() async throws -> [PRInfo] {
        let json = try await ghJSON("pr", "list", "--author", "@me", "--json", "number,title,headRefName,state,url,statusCheckRollup", "--limit", "20")
        return try JSONDecoder().decode([PRInfo].self, from: json)
    }

    static func fetchReviewRequests() async throws -> [PRInfo] {
        let json = try await ghJSON("pr", "list", "--search", "review-requested:@me", "--json", "number,title,headRefName,state,url,statusCheckRollup", "--limit", "20")
        return try JSONDecoder().decode([PRInfo].self, from: json)
    }

    static func fetchAssignedIssues() async throws -> [GitHubIssue] {
        let json = try await ghJSON("issue", "list", "--assignee", "@me", "--json", "number,title,state,url", "--limit", "20")
        return try JSONDecoder().decode([GitHubIssue].self, from: json)
    }

    static func approvePR(number: Int) async throws {
        _ = try await ghJSON("pr", "review", "\(number)", "--approve")
    }

    static func mergePR(number: Int) async throws {
        _ = try await ghJSON("pr", "merge", "\(number)", "--auto", "--squash")
    }

    // MARK: - Helpers

    private static func ghJSON(_ arguments: String...) async throws -> Data {
        guard let gh = ghPath else { throw GitHubError.ghNotFound }
        let output = try await run(gh, arguments: arguments)
        guard let data = output.data(using: .utf8) else { throw GitHubError.invalidOutput }
        return data
    }

    private static func run(_ executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum GitHubError: Error, LocalizedError {
    case ghNotFound
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .ghNotFound: return "GitHub CLI (gh) not found"
        case .invalidOutput: return "Invalid output from gh"
        }
    }
}

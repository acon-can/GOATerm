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
        let json = try await ghJSON("search", "prs", "--author=@me", "--state=open", "--json", "number,title,state,url,repository", "--limit", "20")
        return try JSONDecoder().decode([PRInfo].self, from: json)
    }

    static func fetchReviewRequests() async throws -> [PRInfo] {
        let json = try await ghJSON("search", "prs", "--review-requested=@me", "--state=open", "--json", "number,title,state,url,repository", "--limit", "20")
        return try JSONDecoder().decode([PRInfo].self, from: json)
    }

    static func fetchAssignedIssues() async throws -> [GitHubIssue] {
        let json = try await ghJSON("search", "issues", "--assignee=@me", "--state=open", "--json", "number,title,state,url,repository", "--limit", "20")
        return try JSONDecoder().decode([GitHubIssue].self, from: json)
    }

    static func approvePR(repo: String, number: Int) async throws {
        _ = try await ghJSON("pr", "review", "\(number)", "--approve", "--repo", repo)
    }

    static func mergePR(repo: String, number: Int) async throws {
        _ = try await ghJSON("pr", "merge", "\(number)", "--auto", "--squash", "--repo", repo)
    }

    // MARK: - Local Git Info

    static func fetchLocalGitInfo(in directory: String) async -> LocalGitInfo? {
        let git = "/usr/bin/git"
        let c = ["-C", directory]

        guard let branch = try? await run(git, arguments: c + ["branch", "--show-current"]) else {
            return nil
        }
        let branchName = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        if branchName.isEmpty { return nil }

        let trackingBranch = try? await run(git, arguments: c + ["rev-parse", "--abbrev-ref", "@{upstream}"])
        let tracking = trackingBranch?.trimmingCharacters(in: .whitespacesAndNewlines)

        var ahead = 0
        var behind = 0
        if tracking != nil {
            if let a = try? await run(git, arguments: c + ["rev-list", "--count", "@{upstream}..HEAD"]) {
                ahead = Int(a.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            }
            if let b = try? await run(git, arguments: c + ["rev-list", "--count", "HEAD..@{upstream}"]) {
                behind = Int(b.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            }
        }

        // Parse git status --porcelain
        var staged = 0, modified = 0, untracked = 0, conflicts = 0
        if let status = try? await run(git, arguments: c + ["status", "--porcelain"]) {
            for line in status.split(separator: "\n") where line.count >= 2 {
                let x = line[line.startIndex]
                let y = line[line.index(after: line.startIndex)]
                if x == "U" || y == "U" || (x == "D" && y == "D") || (x == "A" && y == "A") {
                    conflicts += 1
                } else if x == "?" {
                    untracked += 1
                } else {
                    if x != " " && x != "?" { staged += 1 }
                    if y != " " && y != "?" { modified += 1 }
                }
            }
        }

        var stashCount = 0
        if let stash = try? await run(git, arguments: c + ["stash", "list"]) {
            stashCount = stash.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n").count
            if stash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { stashCount = 0 }
        }

        var commits: [GitCommitInfo] = []
        if let log = try? await run(git, arguments: c + ["log", "--oneline", "-8", "--format=%h\t%s\t%an\t%ar"]) {
            for line in log.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 3)
                if parts.count == 4 {
                    commits.append(GitCommitInfo(
                        hash: String(parts[0]),
                        message: String(parts[1]),
                        author: String(parts[2]),
                        relativeDate: String(parts[3])
                    ))
                }
            }
        }

        return LocalGitInfo(
            branch: branchName,
            trackingBranch: tracking,
            ahead: ahead,
            behind: behind,
            stagedCount: staged,
            modifiedCount: modified,
            untrackedCount: untracked,
            conflictCount: conflicts,
            stashCount: stashCount,
            recentCommits: commits
        )
    }

    // MARK: - Branches

    static func fetchBranches(in directory: String) async -> [GitBranchInfo] {
        let git = "/usr/bin/git"
        let c = ["-C", directory]

        // Get the default branch name (main/master) for ahead/behind comparison
        let defaultBranch: String
        if let mainRef = try? await run(git, arguments: c + ["symbolic-ref", "refs/remotes/origin/HEAD", "--short"]) {
            // Returns e.g. "origin/main" → strip "origin/"
            let trimmed = mainRef.trimmingCharacters(in: .whitespacesAndNewlines)
            defaultBranch = trimmed.hasPrefix("origin/") ? String(trimmed.dropFirst(7)) : trimmed
        } else {
            defaultBranch = "main"
        }

        // git branch -a --format with tab-separated fields:
        // refname:short, HEAD indicator, author, relative date
        guard let output = try? await run(git, arguments: c + [
            "branch", "--format=%(refname:short)\t%(HEAD)\t%(authorname)\t%(committerdate:relative)",
            "--sort=-committerdate"
        ]) else { return [] }

        let currentBranch = (try? await run(git, arguments: c + ["branch", "--show-current"]))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var branches: [GitBranchInfo] = []
        for line in output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 3)
            guard parts.count == 4 else { continue }
            let name = String(parts[0])
            let isCurrent = parts[1].trimmingCharacters(in: .whitespaces) == "*"
            let author = String(parts[2])
            let date = String(parts[3])

            // Ahead/behind relative to default branch
            var ahead = 0, behind = 0
            if name != defaultBranch {
                if let ab = try? await run(git, arguments: c + [
                    "rev-list", "--left-right", "--count", "\(defaultBranch)...\(name)"
                ]) {
                    let counts = ab.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
                    if counts.count == 2 {
                        behind = Int(counts[0]) ?? 0
                        ahead = Int(counts[1]) ?? 0
                    }
                }
            }

            branches.append(GitBranchInfo(
                name: name,
                isCurrent: name == currentBranch,
                lastCommitDate: date,
                lastAuthor: author,
                ahead: ahead,
                behind: behind
            ))
        }

        return branches
    }

    // MARK: - Repo Detection

    static func detectRepo(in directory: String) async -> String? {
        guard let url = try? await run("/usr/bin/git", arguments: ["-C", directory, "remote", "get-url", "origin"]) else {
            return nil
        }
        return parseRepoName(from: url.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func parseRepoName(from remoteURL: String) -> String? {
        // SSH: git@github.com:owner/repo.git
        if remoteURL.contains("github.com:"),
           let path = remoteURL.split(separator: ":").last {
            return String(path).replacingOccurrences(of: ".git", with: "")
        }
        // HTTPS: https://github.com/owner/repo.git
        if let url = URL(string: remoteURL),
           url.host?.contains("github.com") == true {
            let comps = url.pathComponents.filter { $0 != "/" }
            if comps.count >= 2 {
                return "\(comps[0])/\(comps[1])".replacingOccurrences(of: ".git", with: "")
            }
        }
        return nil
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

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            throw GitHubError.commandFailed(errMsg)
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum GitHubError: Error, LocalizedError {
    case ghNotFound
    case invalidOutput
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .ghNotFound: return "GitHub CLI (gh) not found"
        case .invalidOutput: return "Invalid output from gh"
        case .commandFailed(let msg): return msg
        }
    }
}

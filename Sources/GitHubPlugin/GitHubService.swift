import Foundation
import OSLog
import StatusBarKit

private let logger = Logger(subsystem: "com.statusbar.github", category: "GitHubService")

enum GitHubServiceError: Error, Equatable {
    case notAuthenticated
    case fetchFailed(String)
    /// /notifications 404 — token lacks the `notifications` scope.
    case notificationsUnsupported
}

/// Wraps the `gh` CLI. All data comes from the GitHub GraphQL API (search) and
/// the REST notifications endpoint, scoped per authenticated account.
final class GitHubService: @unchecked Sendable {
    private static let graphQLQuery = """
        query($authoredQ: String!, $reviewQ: String!) {
          authored: search(query: $authoredQ, type: ISSUE, first: 30) {
            nodes { ...PRFields }
          }
          reviewRequested: search(query: $reviewQ, type: ISSUE, first: 30) {
            nodes { ...PRFields }
          }
        }
        fragment PRFields on PullRequest {
          number title url isDraft state updatedAt headRefName additions deletions
          author { login }
          repository { nameWithOwner }
          reviewDecision
          commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        }
        """

    // MARK: - Accounts

    /// All github.com accounts authenticated in `gh`, active account first.
    func listAccounts() async throws -> [GitHubAccount] {
        let result = try await ShellCommand.runWithResult("gh", arguments: ["auth", "status"], timeout: 10)
        let accounts = GitHubParsing.parseAuthStatus(result.stdout + "\n" + result.stderr)
        guard !accounts.isEmpty else {
            throw GitHubServiceError.notAuthenticated
        }
        return accounts.sorted { $0.isActive && !$1.isActive }
    }

    // MARK: - Fetching

    func fetchPullRequests(account: String) async throws -> (my: [GitHubPullRequest], review: [GitHubPullRequest]) {
        let authoredQ = "is:pr is:open author:\(account)"
        let reviewQ = "is:pr is:open review-requested:\(account) OR is:pr is:open team-review-requested:\(account)"
        let output = try await authed(account) {
            "gh api graphql -f query=\(shellQuote(Self.graphQLQuery)) -f authoredQ=\(shellQuote(authoredQ)) -f reviewQ=\(shellQuote(reviewQ))"
        }

        guard let data = output.data(using: .utf8) else {
            throw GitHubServiceError.fetchFailed("empty response")
        }
        let response = try JSONDecoder().decode(SearchResponseDTO.self, from: data)
        guard let searchData = response.data else {
            let message = response.errors?.first?.message ?? "no data"
            throw GitHubServiceError.fetchFailed(message)
        }

        let my = searchData.authored.nodes.compactMap { $0 }.map { GitHubMapping.pullRequest($0, account: account) }
        var seen = Set(my.map(\.key))
        let review = searchData.reviewRequested.nodes.compactMap { $0 }
            .map { GitHubMapping.pullRequest($0, account: account) }
            .filter { seen.insert($0.key).inserted }
        return (my: my, review: review)
    }

    func fetchNotifications(account: String) async throws -> [GitHubNotification] {
        let result = try await authedResult(account) {
            "gh api notifications -f per_page=50"
        }
        guard result.exitCode == 0 else {
            if result.stderr.contains("404") || result.stdout.contains("HTTP 404") {
                throw GitHubServiceError.notificationsUnsupported
            }
            throw GitHubServiceError.fetchFailed(result.stderr.components(separatedBy: "\n").first ?? "request failed")
        }
        guard let data = result.stdout.data(using: .utf8) else {
            throw GitHubServiceError.fetchFailed("empty response")
        }
        return try JSONDecoder().decode([NotificationDTO].self, from: data)
            .filter(\.unread)
            .map { GitHubMapping.notification($0, account: account) }
    }

    /// Fetch a full snapshot for one account. Section-level failures degrade to
    /// empty lists; a total failure sets `error`.
    func fetchSnapshot(account: GitHubAccount, includeNotifications: Bool) async -> AccountSnapshot {
        var snapshot = AccountSnapshot(login: account.login)
        do {
            let prs = try await fetchPullRequests(account: account.login)
            snapshot.myPRs = prs.my
            snapshot.reviewPRs = prs.review
        } catch {
            logger.debug("fetchPullRequests(\(account.login)) failed: \(error.localizedDescription)")
            snapshot.error = error.localizedDescription
        }
        if includeNotifications {
            do {
                snapshot.notifications = try await fetchNotifications(account: account.login)
            } catch GitHubServiceError.notificationsUnsupported {
                snapshot.notificationsUnsupported = true
            } catch {
                logger.debug("fetchNotifications(\(account.login)) failed: \(error.localizedDescription)")
            }
        }
        return snapshot
    }

    // MARK: - Shell Helpers

    /// Run a command with `GH_TOKEN` resolved for the given account so the plugin
    /// works with non-active gh accounts too.
    private func authed(_ account: String, command: () -> String) async throws -> String {
        let tokenExpr = "$(gh auth token -u \(shellQuote(account)) -h github.com)"
        return try await ShellCommand.run(
            "GH_TOKEN=\(tokenExpr) \(command())",
            timeout: 15
        )
    }

    private func authedResult(_ account: String, command: () -> String) async throws -> ShellCommandResult {
        let tokenExpr = "$(gh auth token -u \(shellQuote(account)) -h github.com)"
        return try await ShellCommand.runWithResult(
            "GH_TOKEN=\(tokenExpr) \(command())",
            timeout: 15
        )
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Parsing

enum GitHubParsing {
    /// Parse `gh auth status` output into accounts. Looks like:
    ///   github.com
    ///     ✓ Logged in to github.com account alice (keyring)
    ///     - Active account: true
    static func parseAuthStatus(_ text: String) -> [GitHubAccount] {
        var accounts: [GitHubAccount] = []
        var pending: GitHubAccount?
        for line in text.split(separator: "\n") {
            if let match = line.firstMatch(of: /Logged in to (\S+) account (\S+)/) {
                if let pending { accounts.append(pending) }
                pending = GitHubAccount(
                    login: String(match.2),
                    host: String(match.1),
                    isActive: false
                )
            } else if pending != nil, line.contains("Active account: true") {
                pending?.isActive = true
            }
        }
        if let pending { accounts.append(pending) }
        return accounts.filter { $0.host == "github.com" && isValidLogin($0.login) }
    }

    /// GitHub logins are alnum + hyphen — reject anything else before shell use.
    static func isValidLogin(_ login: String) -> Bool {
        !login.isEmpty && login.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }
}

// MARK: - Change Detection (pure, for toast dedup)

enum GitHubChanges {
    /// PR keys in `current` that were not in `previousKeys`.
    static func newReviewRequests(previousKeys: Set<String>, current: [GitHubPullRequest]) -> [GitHubPullRequest] {
        current.filter { !previousKeys.contains($0.key) }
    }

    /// PRs whose review decision transitioned to APPROVED or CHANGES_REQUESTED
    /// from a different, previously-known value.
    static func decisionChanges(
        previous: [String: ReviewDecision],
        current: [GitHubPullRequest]
    ) -> [(pr: GitHubPullRequest, decision: ReviewDecision)] {
        current.compactMap { pr in
            guard let old = previous[pr.key],
                old != pr.reviewDecision,
                pr.reviewDecision == .approved || pr.reviewDecision == .changesRequested
            else { return nil }
            return (pr, pr.reviewDecision)
        }
    }
}

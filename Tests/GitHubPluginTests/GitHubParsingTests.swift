import Foundation
@testable import GitHubPlugin
import Testing

struct AuthStatusParsingTests {
    @Test
    func `parses two github.com accounts with active flag`() {
        let text = """
            github.com
              ✓ Logged in to github.com account alice (keyring)
              - Active account: true
              - Git operations protocol: https
              - Token: gho_***

              ✓ Logged in to github.com account bob (keyring)
              - Active account: false
              - Git operations protocol: https
              - Token: gho_***
            """
        let accounts = GitHubParsing.parseAuthStatus(text)
        #expect(accounts == [
            GitHubAccount(login: "alice", host: "github.com", isActive: true),
            GitHubAccount(login: "bob", host: "github.com", isActive: false),
        ])
    }

    @Test
    func `ignores non github.com hosts`() {
        let text = """
            git.example.com
              ✓ Logged in to git.example.com account carol (keyring)
              - Active account: true
            github.com
              ✓ Logged in to github.com account alice (keyring)
              - Active account: false
            """
        let accounts = GitHubParsing.parseAuthStatus(text)
        #expect(accounts.map(\.login) == ["alice"])
    }

    @Test
    func `returns empty on unauthenticated output`() {
        #expect(GitHubParsing.parseAuthStatus("You are not logged in to any hosts").isEmpty)
        #expect(GitHubParsing.parseAuthStatus("").isEmpty)
    }

    @Test
    func `login validation`() {
        #expect(GitHubParsing.isValidLogin("alice-123"))
        #expect(!GitHubParsing.isValidLogin(""))
        #expect(!GitHubParsing.isValidLogin("al'ce"))
        #expect(!GitHubParsing.isValidLogin("a b"))
    }
}

struct NotificationURLTests {
    @Test
    func `pull request api url maps to html url`() {
        let url = GitHubMapping.notificationWebURL(
            apiURL: "https://api.github.com/repos/octo/repo/pulls/42"
        )
        #expect(url == "https://github.com/octo/repo/pull/42")
    }

    @Test
    func `issue and commit urls`() {
        #expect(
            GitHubMapping.notificationWebURL(apiURL: "https://api.github.com/repos/o/r/issues/7")
                == "https://github.com/o/r/issues/7"
        )
        #expect(
            GitHubMapping.notificationWebURL(apiURL: "https://api.github.com/repos/o/r/commits/abc123")
                == "https://github.com/o/r/commit/abc123"
        )
    }

    @Test
    func `nil or unrecognized subjects fall back to inbox`() {
        #expect(GitHubMapping.notificationWebURL(apiURL: nil) == "https://github.com/notifications")
        #expect(
            GitHubMapping.notificationWebURL(apiURL: "https://api.github.com/user")
                == "https://github.com/notifications"
        )
    }
}

struct MappingTests {
    private func prDTOJSON(
        reviewDecision: String? = nil,
        rollupState: String? = nil,
        isDraft: Bool = false
    ) -> String {
        let decision = reviewDecision.map { "\"\($0)\"" } ?? "null"
        let commits: String
        if let rollupState {
            commits = #"{"nodes":[{"commit":{"statusCheckRollup":{"state":"\#(rollupState)"}}}]}"#
        } else {
            commits = #"{"nodes":[]}"#
        }
        return """
            {
              "number": 204,
              "title": "Fix thing",
              "url": "https://github.com/o/r/pull/204",
              "isDraft": \(isDraft),
              "state": "OPEN",
              "updatedAt": "2026-11-13T06:06:29Z",
              "headRefName": "fix/thing",
              "additions": 10,
              "deletions": 2,
              "author": {"login": "alice"},
              "repository": {"nameWithOwner": "o/r"},
              "reviewDecision": \(decision),
              "commits": \(commits)
            }
            """
    }

    private func decode(_ json: String) throws -> PullRequestDTO {
        try JSONDecoder().decode(PullRequestDTO.self, from: Data(json.utf8))
    }

    @Test
    func `maps draft PR with approved decision and green checks`() throws {
        let dto = try decode(prDTOJSON(reviewDecision: "APPROVED", rollupState: "SUCCESS", isDraft: true))
        let pr = GitHubMapping.pullRequest(dto, account: "alice")
        #expect(pr.id == "o/r#204")
        #expect(pr.isDraft)
        #expect(pr.reviewDecision == .approved)
        #expect(pr.checkState == .success)
        #expect(pr.author == "alice")
        #expect(pr.account == "alice")
        #expect(pr.key == "alice|o/r#204")
    }

    @Test
    func `maps missing decision and failed checks`() throws {
        let dto = try decode(prDTOJSON(rollupState: "FAILURE"))
        let pr = GitHubMapping.pullRequest(dto, account: "bob")
        #expect(pr.reviewDecision == .none)
        #expect(pr.checkState == .failure)
    }

    @Test
    func `pending check states`() throws {
        for state in ["PENDING", "EXPECTED"] {
            let dto = try decode(prDTOJSON(rollupState: state))
            #expect(GitHubMapping.pullRequest(dto, account: "a").checkState == .pending)
        }
        let dto = try decode(prDTOJSON())
        #expect(GitHubMapping.pullRequest(dto, account: "a").checkState == .none)
    }

    @Test
    func `iso8601 date parsing`() {
        #expect(GitHubMapping.parseDate("2026-11-13T06:06:29Z") != nil)
        #expect(GitHubMapping.parseDate("2026-11-13T06:06:29.123Z") != nil)
        #expect(GitHubMapping.parseDate("not a date") == nil)
    }
}

struct ChangeDetectionTests {
    private func pr(_ key: String, decision: ReviewDecision = .reviewRequired) -> GitHubPullRequest {
        // key format is "account|id"; split it back into the model fields.
        let parts = key.split(separator: "|", maxSplits: 1)
        return GitHubPullRequest(
            id: String(parts[1]),
            number: 1,
            title: "t",
            url: "https://github.com/o/r/pull/1",
            repo: "o/r",
            isDraft: false,
            updatedAt: Date(),
            headRef: nil,
            author: "x",
            reviewDecision: decision,
            checkState: .none,
            account: String(parts[0])
        )
    }

    @Test
    func `detects new review requests only`() {
        let existing = pr("a|o/r#1")
        let new = pr("a|o/r#2")
        #expect(GitHubChanges.newReviewRequests(previousKeys: [existing.key], current: [existing, new]).map(\.key) == [new.key])
        #expect(GitHubChanges.newReviewRequests(previousKeys: [existing.key, new.key], current: [existing, new]).isEmpty)
    }

    @Test
    func `detects decision transitions to terminal states`() {
        let key = "a|o/r#1"
        #expect(
            GitHubChanges.decisionChanges(
                previous: [key: .reviewRequired],
                current: [pr(key, decision: .approved)]
            ).count == 1
        )
        #expect(
            GitHubChanges.decisionChanges(
                previous: [key: .reviewRequired],
                current: [pr(key, decision: .changesRequested)]
            ).count == 1
        )
    }

    @Test
    func `ignores unchanged, unknown, and non-terminal decisions`() {
        let key = "a|o/r#1"
        #expect(GitHubChanges.decisionChanges(previous: [key: .approved], current: [pr(key, decision: .approved)]).isEmpty)
        // Not previously tracked — seeded silently, no toast.
        #expect(GitHubChanges.decisionChanges(previous: [:], current: [pr(key, decision: .approved)]).isEmpty)
        // Transition to a non-terminal state doesn't toast.
        #expect(GitHubChanges.decisionChanges(previous: [key: .approved], current: [pr(key, decision: .reviewRequired)]).isEmpty)
    }
}

struct RelativeTimeTests {
    @Test
    func `formats compact relative times`() {
        let now = Date()
        #expect(RelativeTime.string(from: now.addingTimeInterval(-30), to: now) == "30s")
        #expect(RelativeTime.string(from: now.addingTimeInterval(-600), to: now) == "10m")
        #expect(RelativeTime.string(from: now.addingTimeInterval(-7200), to: now) == "2h")
        #expect(RelativeTime.string(from: now.addingTimeInterval(-172_800), to: now) == "2d")
        #expect(RelativeTime.string(from: now.addingTimeInterval(-5_184_000), to: now) == "2mo")
    }
}

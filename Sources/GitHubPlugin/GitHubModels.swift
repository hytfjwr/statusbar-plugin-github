import Foundation

// MARK: - Domain Models

/// A gh-authenticated GitHub account discovered via `gh auth status`.
struct GitHubAccount: Sendable, Equatable {
    let login: String
    let host: String
    var isActive: Bool
}

enum ReviewDecision: String, Sendable, Equatable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
    case none
}

enum CheckState: Sendable, Equatable {
    case success
    case pending
    case failure
    case none
}

struct GitHubPullRequest: Sendable, Equatable {
    /// `owner/repo#number` — unique within one account.
    let id: String
    let number: Int
    let title: String
    let url: String
    let repo: String
    let isDraft: Bool
    let updatedAt: Date
    let headRef: String?
    let author: String
    let reviewDecision: ReviewDecision
    let checkState: CheckState
    /// gh login this row is associated with (author query or review request target).
    let account: String

    /// Unique across accounts (same PR can surface under two accounts' queries).
    var key: String { "\(account)|\(id)" }
}

struct GitHubNotification: Sendable, Identifiable, Equatable {
    let id: String
    let repo: String
    let reason: String
    let title: String
    let type: String
    let webURL: String
    let updatedAt: Date
    let account: String

    var key: String { "\(account)|\(id)" }
}

/// Per-account fetch result. Partial failures keep the sections that succeeded.
struct AccountSnapshot: Sendable, Equatable {
    var login: String
    var myPRs: [GitHubPullRequest] = []
    var reviewPRs: [GitHubPullRequest] = []
    var notifications: [GitHubNotification] = []
    /// The account's token lacks the `notifications` scope (/notifications 404).
    var notificationsUnsupported = false
    /// Non-nil when every request for this account failed.
    var error: String?
}

/// Popup sections, orderable via the `sectionOrder` setting.
enum PopupSection: String, Sendable, CaseIterable {
    case review
    case mine
    case notifications

    /// Parse a comma-separated order string. Unknown tokens are dropped,
    /// duplicates collapse, and omitted sections append in default order.
    static func parseOrder(_ string: String) -> [PopupSection] {
        var seen = Set<PopupSection>()
        var ordered = string
            .split(separator: ",")
            .compactMap { PopupSection(rawValue: $0.trimmingCharacters(in: .whitespaces).lowercased()) }
            .filter { seen.insert($0).inserted }
        ordered += PopupSection.allCases.filter { !seen.contains($0) }
        return ordered
    }
}

// MARK: - GraphQL Wire Types

struct SearchResponseDTO: Decodable {
    let data: SearchDataDTO?
    let errors: [GraphQLErrorDTO]?

    struct GraphQLErrorDTO: Decodable {
        let message: String
    }
}

struct SearchDataDTO: Decodable {
    let authored: SearchResultDTO
    let reviewRequested: SearchResultDTO
}

struct SearchResultDTO: Decodable {
    let nodes: [PullRequestDTO?]
}

struct PullRequestDTO: Decodable {
    let number: Int
    let title: String
    let url: String
    let isDraft: Bool
    let updatedAt: String
    let headRefName: String?
    let additions: Int?
    let deletions: Int?
    let author: AuthorDTO?
    let repository: RepoDTO
    let reviewDecision: String?
    let commits: CommitNodesDTO?

    struct AuthorDTO: Decodable {
        let login: String
    }

    struct RepoDTO: Decodable {
        let nameWithOwner: String
    }

    struct CommitNodesDTO: Decodable {
        let nodes: [CommitNodeDTO?]
    }

    struct CommitNodeDTO: Decodable {
        let commit: CommitDTO
    }

    struct CommitDTO: Decodable {
        let statusCheckRollup: StatusCheckRollupDTO?
    }

    struct StatusCheckRollupDTO: Decodable {
        let state: String
    }
}

// MARK: - REST Notification Wire Type

struct NotificationDTO: Decodable {
    let id: String
    let reason: String
    let unread: Bool
    let updatedAt: String
    let subject: SubjectDTO
    let repository: RepoDTO

    enum CodingKeys: String, CodingKey {
        case id, reason, unread
        case updatedAt = "updated_at"
        case subject, repository
    }

    struct SubjectDTO: Decodable {
        let title: String
        let type: String
        let url: String?
    }

    struct RepoDTO: Decodable {
        let fullName: String

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }
}

// MARK: - Mapping

enum GitHubMapping {
    static func pullRequest(_ dto: PullRequestDTO, account: String) -> GitHubPullRequest {
        GitHubPullRequest(
            id: "\(dto.repository.nameWithOwner)#\(dto.number)",
            number: dto.number,
            title: dto.title,
            url: dto.url,
            repo: dto.repository.nameWithOwner,
            isDraft: dto.isDraft,
            updatedAt: parseDate(dto.updatedAt) ?? .distantPast,
            headRef: dto.headRefName,
            author: dto.author?.login ?? "",
            reviewDecision: ReviewDecision(rawValue: dto.reviewDecision ?? "") ?? .none,
            checkState: checkState(from: dto),
            account: account
        )
    }

    static func notification(_ dto: NotificationDTO, account: String) -> GitHubNotification {
        GitHubNotification(
            id: dto.id,
            repo: dto.repository.fullName,
            reason: dto.reason,
            title: dto.subject.title,
            type: dto.subject.type,
            webURL: notificationWebURL(apiURL: dto.subject.url),
            updatedAt: parseDate(dto.updatedAt) ?? .distantPast,
            account: account
        )
    }

    static func checkState(from dto: PullRequestDTO) -> CheckState {
        guard let state = dto.commits?.nodes.lazy.compactMap({ $0?.commit.statusCheckRollup?.state }).first else {
            return .none
        }
        switch state {
        case "SUCCESS": return .success
        case "FAILURE", "ERROR": return .failure
        case "PENDING", "EXPECTED": return .pending
        default: return .none
        }
    }

    /// Convert an api.github.com URL to its github.com page, falling back to the
    /// notifications inbox when the subject has no URL (e.g. WorkflowRun subjects).
    static func notificationWebURL(apiURL: String?) -> String {
        let prefix = "https://api.github.com/repos/"
        guard let apiURL, apiURL.hasPrefix(prefix) else {
            return "https://github.com/notifications"
        }
        var rest = String(apiURL.dropFirst(prefix.count))
        guard !rest.isEmpty else {
            return "https://github.com/notifications"
        }
        for (api, web) in [("/pulls/", "/pull/"), ("/issues/", "/issues/"), ("/commits/", "/commit/")] {
            if let range = rest.range(of: api) {
                rest.replaceSubrange(range, with: web)
                return "https://github.com/\(rest)"
            }
        }
        return "https://github.com/notifications"
    }

    static func parseDate(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: .iso8601) {
            return date
        }
        return try? Date(
            string,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        )
    }
}

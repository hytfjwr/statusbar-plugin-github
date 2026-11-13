import StatusBarKit
import SwiftUI

// MARK: - Popup Content

struct GitHubPopupContent: View {
    let snapshots: [AccountSnapshot]
    let ghAvailable: Bool
    let loadError: String?
    let fetching: Bool
    let lastUpdated: Date?
    let showNotifications: Bool
    let multiAccount: Bool
    let onOpenURL: (String) -> Void
    let onRefresh: () -> Void

    private var reviewPRs: [GitHubPullRequest] {
        snapshots.flatMap(\.reviewPRs).sorted { $0.updatedAt > $1.updatedAt }
    }

    private var myPRs: [GitHubPullRequest] {
        snapshots.flatMap(\.myPRs).sorted { $0.updatedAt > $1.updatedAt }
    }

    private var notifications: [GitHubNotification] {
        snapshots.flatMap(\.notifications).sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !ghAvailable {
                PopupEmptyState(icon: "person.crop.circle.badge.exclam", message: "Not signed in to GitHub")
                hintRow("Run `gh auth login` to connect an account")
            } else {
                if loadError != nil {
                    errorRow("Refresh failed — showing last data")
                }
                let failedAccounts = snapshots.filter { $0.error != nil }
                if !failedAccounts.isEmpty {
                    ForEach(failedAccounts, id: \.login) { snapshot in
                        errorRow("Failed to load @\(snapshot.login)")
                    }
                }

                if snapshots.isEmpty || (reviewPRs.isEmpty && myPRs.isEmpty && notifications.isEmpty && failedAccounts.isEmpty) {
                    PopupEmptyState(icon: "checkmark.circle", message: fetching ? "Loading…" : "All caught up")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !reviewPRs.isEmpty {
                                sectionHeader("Review Requested", count: reviewPRs.count, color: Theme.yellow)
                                ForEach(reviewPRs, id: \.key) { pr in
                                    PRRowView(pr: pr, role: .reviewRequested, showAccount: multiAccount, onOpen: onOpenURL)
                                }
                            }

                            if !myPRs.isEmpty {
                                if !reviewPRs.isEmpty { PopupDivider() }
                                sectionHeader("My Pull Requests", count: myPRs.count, color: Theme.accentBlue)
                                ForEach(myPRs, id: \.key) { pr in
                                    PRRowView(pr: pr, role: .authored, showAccount: multiAccount, onOpen: onOpenURL)
                                }
                            }

                            if showNotifications && !notifications.isEmpty {
                                if !reviewPRs.isEmpty || !myPRs.isEmpty { PopupDivider() }
                                sectionHeader("Notifications", count: notifications.count, color: Theme.secondary)
                                ForEach(notifications.prefix(20), id: \.key) { notification in
                                    NotificationRowView(notification: notification, showAccount: multiAccount, onOpen: onOpenURL)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 460)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 8) {
            GitHubMarkShape()
                .fill(Theme.accentBlue)
                .frame(width: 12, height: 12)
            Text("GITHUB")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)

            Spacer()

            if fetching {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            } else if let lastUpdated {
                Text(RelativeTime.string(from: lastUpdated))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.secondary)
            }
            .buttonStyle(.plain)
            .disabled(fetching)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack {
            PopupSectionHeader(title)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(Capsule().fill(color.opacity(0.12)))
                .padding(.trailing, 14)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.yellow)
            Text(message)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
    }
}

// MARK: - PR Row

enum PRRowRole {
    case authored
    case reviewRequested
}

private struct PRRowView: View {
    let pr: GitHubPullRequest
    let role: PRRowRole
    let showAccount: Bool
    let onOpen: (String) -> Void

    var body: some View {
        Button(action: { onOpen(pr.url) }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: leadingIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(leadingColor)
                        .frame(width: 16)

                    Text("\(pr.repo)#\(pr.number)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    trailingBadges
                }

                Text(pr.title)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(pr.isDraft ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 22)

                HStack(spacing: 5) {
                    if role == .reviewRequested, !pr.author.isEmpty {
                        metaItem("person", pr.author)
                    }
                    if role == .authored, let headRef = pr.headRef {
                        metaItem("arrow.triangle.branch", headRef)
                    }
                    metaItem("clock", RelativeTime.string(from: pr.updatedAt))
                    if showAccount {
                        accountBadge(pr.account)
                    }
                }
                .padding(.leading, 22)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: Theme.popupItemCornerRadius, style: .continuous))
        }
        .buttonStyle(PopupButtonStyle())
    }

    private var leadingIcon: String {
        role == .reviewRequested ? "eye.fill" : "arrow.triangle.pull"
    }

    private var leadingColor: Color {
        role == .reviewRequested ? Theme.yellow : Theme.accentBlue
    }

    @ViewBuilder
    private var trailingBadges: some View {
        if pr.isDraft {
            PopupStatusBadge("DRAFT", color: .secondary)
        }
        switch pr.reviewDecision {
        case .approved:
            PopupStatusBadge("APPROVED", color: Theme.green)
        case .changesRequested:
            PopupStatusBadge("CHANGES", color: Theme.red)
        case .reviewRequired:
            PopupStatusBadge("REVIEW REQ", color: Theme.yellow)
        case .none:
            EmptyView()
        }
        switch pr.checkState {
        case .success:
            checkDot(Theme.green)
        case .pending:
            checkDot(Theme.yellow)
        case .failure:
            checkDot(Theme.red)
        case .none:
            EmptyView()
        }
    }

    private func checkDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }

    private func metaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.tertiary)
    }

    private func accountBadge(_ login: String) -> some View {
        Text("@\(login)")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.accentBlue)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Theme.accentBlue.opacity(0.1)))
    }
}

// MARK: - Notification Row

private struct NotificationRowView: View {
    let notification: GitHubNotification
    let showAccount: Bool
    let onOpen: (String) -> Void

    var body: some View {
        Button(action: { onOpen(notification.webURL) }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: typeIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(typeColor)
                        .frame(width: 16)

                    Text(notification.repo)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(reasonLabel)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.purple.opacity(0.1)))
                }

                Text(notification.title)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 22)

                HStack(spacing: 5) {
                    metaItem("clock", RelativeTime.string(from: notification.updatedAt))
                    if showAccount {
                        Text("@\(notification.account)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.accentBlue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.accentBlue.opacity(0.1)))
                    }
                }
                .padding(.leading, 22)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: Theme.popupItemCornerRadius, style: .continuous))
        }
        .buttonStyle(PopupButtonStyle())
    }

    private var typeIcon: String {
        switch notification.type {
        case "PullRequest": "arrow.triangle.pull"
        case "Issue": "exclamationmark.circle"
        case "CheckSuite", "CheckRun": "xmark.octagon"
        case "WorkflowRun", "WorkflowJob": "gearshape.2"
        case "Release": "tag"
        case "Discussion": "bubble.left"
        case "Commit": "arrow.triangle.branch"
        case "RepositoryVulnerabilityAlert": "lock.trianglebadge.exclamationmark"
        default: "bell"
        }
    }

    private var typeColor: Color {
        switch notification.type {
        case "CheckSuite", "CheckRun", "WorkflowRun", "WorkflowJob": Theme.red
        case "RepositoryVulnerabilityAlert": Theme.yellow
        default: Theme.secondary
        }
    }

    private var reasonLabel: String {
        switch notification.reason {
        case "review_requested": "Review"
        case "assign": "Assigned"
        case "mention": "Mention"
        case "team_mention": "Team"
        case "comment": "Comment"
        case "ci_activity": "CI"
        case "approval_requested": "Approval"
        case "state_change": "State"
        case "security_alert": "Security"
        case "author": "Author"
        case "subscribed": "Subscribed"
        default: notification.reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func metaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.tertiary)
    }
}

// MARK: - Relative Time

enum RelativeTime {
    /// "45s" / "12m" / "3h" / "2d" style relative timestamp.
    static func string(from date: Date, to now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 30 { return "\(days)d" }
        let months = days / 30
        if months < 12 { return "\(months)mo" }
        return "\(months / 12)y"
    }
}

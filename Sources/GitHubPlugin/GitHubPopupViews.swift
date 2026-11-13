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
    let sectionOrder: [PopupSection]
    let onOpenURL: (String) -> Void
    let onRefresh: () -> Void
    let onMoveSection: (PopupSection, Int) -> Void

    @State private var hoveredSection: PopupSection?

    private var reviewPRs: [GitHubPullRequest] {
        snapshots.flatMap(\.reviewPRs).sorted { $0.updatedAt > $1.updatedAt }
    }

    private var myPRs: [GitHubPullRequest] {
        snapshots.flatMap(\.myPRs).sorted { $0.updatedAt > $1.updatedAt }
    }

    private var notifications: [GitHubNotification] {
        snapshots.flatMap(\.notifications).sorted { $0.updatedAt > $1.updatedAt }
    }

    private var visibleSections: [PopupSection] {
        sectionOrder.filter { section in
            switch section {
            case .review: !reviewPRs.isEmpty
            case .mine: !myPRs.isEmpty
            case .notifications: showNotifications && !notifications.isEmpty
            }
        }
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

                if showNotifications && snapshots.contains(where: \.notificationsUnsupported) {
                    hintRow("Notifications need the `notifications` scope — run `gh auth refresh -s notifications`")
                }

                if snapshots.isEmpty || (visibleSections.isEmpty && failedAccounts.isEmpty) {
                    PopupEmptyState(icon: "checkmark.circle", message: fetching ? "Loading…" : "All caught up")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(visibleSections.enumerated()), id: \.element) { index, section in
                                if index > 0 { PopupDivider() }
                                sectionContent(
                                    section,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < visibleSections.count - 1
                                )
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

    @ViewBuilder
    private func sectionContent(_ section: PopupSection, canMoveUp: Bool, canMoveDown: Bool) -> some View {
        switch section {
        case .review:
            sectionHeader("Review Requested", count: reviewPRs.count, color: Theme.yellow,
                          section: section, canMoveUp: canMoveUp, canMoveDown: canMoveDown)
            ForEach(reviewPRs, id: \.key) { pr in
                PRRowView(pr: pr, role: .reviewRequested, showAccount: multiAccount, onOpen: onOpenURL)
            }
        case .mine:
            sectionHeader("My Pull Requests", count: myPRs.count, color: Theme.accentBlue,
                          section: section, canMoveUp: canMoveUp, canMoveDown: canMoveDown)
            ForEach(myPRs, id: \.key) { pr in
                PRRowView(pr: pr, role: .authored, showAccount: multiAccount, onOpen: onOpenURL)
            }
        case .notifications:
            sectionHeader("Notifications", count: notifications.count, color: Theme.secondary,
                          section: section, canMoveUp: canMoveUp, canMoveDown: canMoveDown)
            ForEach(notifications.prefix(20), id: \.key) { notification in
                NotificationRowView(notification: notification, showAccount: multiAccount, onOpen: onOpenURL)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            GitHubMarkShape(style: .cat)
                .fill(Theme.accentBlue, style: FillStyle(eoFill: true))
                .frame(width: 13, height: 13)
            Text("GITHUB")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))

            Spacer()

            if fetching {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            } else if let lastUpdated {
                Text(RelativeTime.string(from: lastUpdated))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(fetching)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func sectionHeader(
        _ title: String, count: Int, color: Color,
        section: PopupSection, canMoveUp: Bool, canMoveDown: Bool
    ) -> some View {
        HStack(spacing: 4) {
            PopupSectionHeader(title)
            Spacer()

            HStack(spacing: 2) {
                moveButton("chevron.up", section: section, direction: -1, enabled: canMoveUp)
                moveButton("chevron.down", section: section, direction: 1, enabled: canMoveDown)
            }
            .opacity(hoveredSection == section ? 1 : 0)

            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(Capsule().fill(color.opacity(0.22)))
        }
        .padding(.trailing, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredSection = hovering ? section : nil
        }
    }

    private func moveButton(
        _ symbol: String, section: PopupSection, direction: Int, enabled: Bool
    ) -> some View {
        Button {
            onMoveSection(section, direction)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
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
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(leadingColor)
                        .frame(width: 16)

                    Text("\(pr.repo)#\(pr.number)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
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
        .foregroundStyle(.secondary)
    }

    private func accountBadge(_ login: String) -> some View {
        Text("@\(login)")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.accentBlue)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Theme.accentBlue.opacity(0.22)))
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(typeColor)
                        .frame(width: 16)

                    Text(notification.repo)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(reasonLabel)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.purple.opacity(0.22)))
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
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.accentBlue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.accentBlue.opacity(0.22)))
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
        default: .primary.opacity(0.7)
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
        .foregroundStyle(.secondary)
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

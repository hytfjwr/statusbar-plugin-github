import Combine
import StatusBarKit
import SwiftUI

@MainActor
@Observable
public final class GitHubWidget: StatusBarWidget {
    public let id = "github"
    public let position: WidgetPosition = .right
    public let updateInterval: TimeInterval? = nil
    public let sfSymbolName = "arrow.triangle.pull"
    public let preferredSettingsSize: CGSize? = CGSize(width: 400, height: 560)

    public var subscribedEvents: [String] { ["refresh"] }

    private let service = GitHubService()
    private var timer: AnyCancellable?
    private var popupPanel: PopupPanel?

    private var snapshots: [AccountSnapshot] = []
    private var ghAvailable = true
    private var loadError: String?
    private var fetching = false
    private var lastUpdated: Date?

    // Toast dedup state. Seeded silently on the first successful fetch so
    // pre-existing review requests don't toast at startup.
    private var seeded = false
    private var seenReviewKeys: Set<String> = []
    private var seenDecisions: [String: ReviewDecision] = [:]

    private var settings: GitHubSettings { GitHubSettings.shared }

    private var reviewCount: Int {
        snapshots.reduce(0) { $0 + $1.reviewPRs.count }
    }

    private var myPRCount: Int {
        snapshots.reduce(0) { $0 + $1.myPRs.count }
    }

    private var hasError: Bool {
        !ghAvailable || loadError != nil || snapshots.contains { $0.error != nil }
    }

    public init() {}

    public func start() {
        refresh()
        restartTimer()
        observeSettings()
    }

    public func stop() {
        timer?.cancel()
        popupPanel?.hidePopup()
    }

    public func handleEvent(_ event: PluginEvent) {
        guard event.name.hasSuffix(".refresh") else { return }
        refresh()
    }

    public func settingsBody() -> some View {
        GitHubSettingsView()
    }

    public func body() -> some View {
        HStack(spacing: 4) {
            if reviewCount > 0 {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.yellow)
                Text("\(reviewCount)")
                    .font(Theme.labelFont)
                    .foregroundStyle(Theme.yellow)
            }

            GitHubMarkShape(style: .cat)
                .fill(iconColor, style: FillStyle(eoFill: true))
                .frame(width: 15, height: 15)

            if settings.showBarCounts && myPRCount > 0 {
                Text("\(myPRCount)")
                    .font(Theme.labelFont)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture { [weak self] in
            self?.togglePopup()
        }
    }

    private var iconColor: Color {
        if hasError { return Theme.red }
        if !ghAvailable || snapshots.isEmpty { return Theme.secondary }
        return .primary
    }

    // MARK: - Refresh

    private func restartTimer() {
        timer?.cancel()
        let interval = max(settings.refreshInterval, 15)
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settings.accounts
            _ = settings.refreshInterval
            _ = settings.showNotifications
            _ = settings.showBarCounts
            _ = settings.toastOnReviewRequest
            _ = settings.toastOnReviewDecision
            _ = settings.sectionOrder
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.restartTimer()
                self.refresh()
                self.observeSettings()
            }
        }
    }

    private func refresh() {
        guard !fetching else { return }
        fetching = true
        Task { @MainActor in
            defer {
                fetching = false
                lastUpdated = Date()
                if popupPanel?.isVisible == true {
                    popupPanel?.updateContent(makePopupContent())
                    popupPanel?.resizeToFitContent()
                }
            }

            let includeNotifications = settings.showNotifications
            do {
                var accounts = try await service.listAccounts()
                if let logins = settings.configuredLogins {
                    accounts = logins.map { GitHubAccount(login: $0, host: "github.com", isActive: false) }
                }
                ghAvailable = true
                loadError = nil
                let newSnapshots = await withTaskGroup(of: AccountSnapshot.self) { group in
                    for account in accounts {
                        group.addTask { [service] in
                            await service.fetchSnapshot(account: account, includeNotifications: includeNotifications)
                        }
                    }
                    var results: [AccountSnapshot] = []
                    for await snapshot in group {
                        results.append(snapshot)
                    }
                    return results.sorted { $0.login < $1.login }
                }
                processToasts(newSnapshots)
                snapshots = newSnapshots
            } catch GitHubServiceError.notAuthenticated {
                ghAvailable = false
                snapshots = []
            } catch {
                // Transient failure — keep the last good snapshot and flag it.
                loadError = error.localizedDescription
            }
        }
    }

    // MARK: - Toasts

    private func processToasts(_ new: [AccountSnapshot]) {
        let allReview = new.flatMap(\.reviewPRs)
        let allMine = new.flatMap(\.myPRs)
        defer {
            seenReviewKeys = Set(allReview.map(\.key))
            seenDecisions = Dictionary(uniqueKeysWithValues: allMine.map { ($0.key, $0.reviewDecision) })
            seeded = true
        }
        guard seeded else { return }

        if settings.toastOnReviewRequest {
            for pr in GitHubChanges.newReviewRequests(previousKeys: seenReviewKeys, current: allReview).prefix(3) {
                ToastService.shared.post(ToastRequest(
                    title: "Review requested",
                    message: "\(pr.id) — \(pr.title)",
                    icon: "eye.fill",
                    level: .info,
                    duration: 10,
                    actionLabel: "Open",
                    actionShellCommand: "open '\(pr.url)'"
                ))
            }
        }

        if settings.toastOnReviewDecision {
            for change in GitHubChanges.decisionChanges(previous: seenDecisions, current: allMine).prefix(3) {
                let approved = change.decision == .approved
                ToastService.shared.post(ToastRequest(
                    title: approved ? "PR approved" : "Changes requested",
                    message: "\(change.pr.id) — \(change.pr.title)",
                    icon: approved ? "checkmark.circle.fill" : "exclamationmark.bubble.fill",
                    level: approved ? .success : .warning,
                    duration: 10,
                    actionLabel: "Open",
                    actionShellCommand: "open '\(change.pr.url)'"
                ))
            }
        }
    }

    // MARK: - Popup

    private func togglePopup() {
        if popupPanel?.isVisible == true {
            popupPanel?.hidePopup()
        } else {
            showPopup()
        }
    }

    private func showPopup() {
        if popupPanel == nil {
            popupPanel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 300))
        }
        guard let (barFrame, screen) = PopupPanel.barTriggerFrame() else { return }
        popupPanel?.showPopup(relativeTo: barFrame, on: screen, content: makePopupContent())
    }

    private func makePopupContent() -> GitHubPopupContent {
        GitHubPopupContent(
            snapshots: snapshots,
            ghAvailable: ghAvailable,
            loadError: loadError,
            fetching: fetching,
            lastUpdated: lastUpdated,
            showNotifications: settings.showNotifications,
            multiAccount: snapshots.count > 1,
            sectionOrder: settings.orderedSections,
            onOpenURL: { url in
                Task { _ = try? await ShellCommand.run("open", arguments: [url]) }
            },
            onRefresh: { [weak self] in self?.refresh() },
            onMoveSection: { [weak self] section, direction in
                self?.moveSection(section, direction)
            }
        )
    }

    /// Swap a section with its adjacent *visible* neighbor, leaving hidden
    /// sections in place, then persist via the sectionOrder setting.
    private func moveSection(_ section: PopupSection, _ direction: Int) {
        let full = settings.orderedSections
        let visible = Set(full.filter { s in
            switch s {
            case .review: snapshots.contains { !$0.reviewPRs.isEmpty }
            case .mine: snapshots.contains { !$0.myPRs.isEmpty }
            case .notifications: settings.showNotifications && snapshots.contains { !$0.notifications.isEmpty }
            }
        })
        var visOrder = full.filter { visible.contains($0) }
        guard let idx = visOrder.firstIndex(of: section),
              visOrder.indices.contains(idx + direction) else { return }
        visOrder.swapAt(idx, idx + direction)
        var iter = visOrder.makeIterator()
        settings.sectionOrder = full
            .map { visible.contains($0) ? iter.next()! : $0 }
            .map(\.rawValue)
            .joined(separator: ",")
        popupPanel?.updateContent(makePopupContent())
        popupPanel?.resizeToFitContent()
    }
}

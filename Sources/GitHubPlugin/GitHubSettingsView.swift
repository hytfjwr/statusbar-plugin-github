import StatusBarKit
import SwiftUI

struct GitHubSettingsView: View {
    @State private var accounts: String
    @State private var refreshInterval: Double
    @State private var showNotifications: Bool
    @State private var showBarCounts: Bool
    @State private var toastOnReviewRequest: Bool
    @State private var toastOnReviewDecision: Bool
    @State private var sectionOrder: String

    init() {
        let s = GitHubSettings.shared
        _accounts = State(initialValue: s.accounts)
        _refreshInterval = State(initialValue: s.refreshInterval)
        _showNotifications = State(initialValue: s.showNotifications)
        _showBarCounts = State(initialValue: s.showBarCounts)
        _toastOnReviewRequest = State(initialValue: s.toastOnReviewRequest)
        _toastOnReviewDecision = State(initialValue: s.toastOnReviewDecision)
        _sectionOrder = State(initialValue: s.sectionOrder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Accounts
            VStack(alignment: .leading, spacing: 6) {
                Text("Accounts")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("auto (all gh accounts)", text: $accounts)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: accounts) { _, newValue in
                        GitHubSettings.shared.accounts = newValue
                    }

                Text("Comma-separated gh logins (e.g. work, personal). Leave empty to use every account signed in to the gh CLI.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Refresh
            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh Interval")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("30s").tag(30.0)
                    Text("1m").tag(60.0)
                    Text("2m").tag(120.0)
                    Text("5m").tag(300.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: refreshInterval) { _, newValue in
                    GitHubSettings.shared.refreshInterval = newValue
                }
            }

            Divider()

            // Display
            VStack(alignment: .leading, spacing: 8) {
                Text("Display")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Toggle("Show PR count in the bar", isOn: $showBarCounts)
                    .onChange(of: showBarCounts) { _, newValue in
                        GitHubSettings.shared.showBarCounts = newValue
                    }

                Toggle("Show unread notifications", isOn: $showNotifications)
                    .onChange(of: showNotifications) { _, newValue in
                        GitHubSettings.shared.showNotifications = newValue
                    }

                TextField("review,mine,notifications", text: $sectionOrder)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: sectionOrder) { _, newValue in
                        GitHubSettings.shared.sectionOrder = newValue
                    }

                Text("Popup section order — comma-separated: review, mine, notifications.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .toggleStyle(.switch)
            .font(.system(size: 12))

            Divider()

            // Toasts
            VStack(alignment: .leading, spacing: 8) {
                Text("Toast Notifications")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Toggle("New review requests", isOn: $toastOnReviewRequest)
                    .onChange(of: toastOnReviewRequest) { _, newValue in
                        GitHubSettings.shared.toastOnReviewRequest = newValue
                    }

                Toggle("PR approved / changes requested", isOn: $toastOnReviewDecision)
                    .onChange(of: toastOnReviewDecision) { _, newValue in
                        GitHubSettings.shared.toastOnReviewDecision = newValue
                    }
            }
            .toggleStyle(.switch)
            .font(.system(size: 12))

            Spacer()
        }
        .padding(16)
    }
}

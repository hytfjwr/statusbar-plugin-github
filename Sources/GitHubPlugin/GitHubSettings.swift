import Foundation
import StatusBarKit

@MainActor
@Observable
final class GitHubSettings: WidgetConfigProvider {
    static let shared = GitHubSettings()

    let configID = "github"
    private var suppressWrite = false

    /// Comma-separated gh logins. Empty = every account in `gh auth status`.
    var accounts: String {
        didSet { if !suppressWrite { WidgetConfigRegistry.shared.notifySettingsChanged() } }
    }

    var refreshInterval: Double {
        didSet { if !suppressWrite { WidgetConfigRegistry.shared.notifySettingsChanged() } }
    }

    var showNotifications: Bool {
        didSet { if !suppressWrite { WidgetConfigRegistry.shared.notifySettingsChanged() } }
    }

    var showBarCounts: Bool {
        didSet { if !suppressWrite { WidgetConfigRegistry.shared.notifySettingsChanged() } }
    }

    var toastOnReviewRequest: Bool {
        didSet { if !suppressWrite { WidgetConfigRegistry.shared.notifySettingsChanged() } }
    }

    var toastOnReviewDecision: Bool {
        didSet { if !suppressWrite { WidgetConfigRegistry.shared.notifySettingsChanged() } }
    }

    private init() {
        let cfg = WidgetConfigRegistry.shared.values(for: configID)
        accounts = cfg?["accounts"]?.stringValue ?? ""
        refreshInterval = cfg?["refreshInterval"]?.doubleValue ?? 60
        showNotifications = cfg?["showNotifications"]?.boolValue ?? true
        showBarCounts = cfg?["showBarCounts"]?.boolValue ?? true
        toastOnReviewRequest = cfg?["toastOnReviewRequest"]?.boolValue ?? true
        toastOnReviewDecision = cfg?["toastOnReviewDecision"]?.boolValue ?? true
        WidgetConfigRegistry.shared.register(self)
    }

    func exportConfig() -> [String: ConfigValue] {
        [
            "accounts": .string(accounts),
            "refreshInterval": .double(refreshInterval),
            "showNotifications": .bool(showNotifications),
            "showBarCounts": .bool(showBarCounts),
            "toastOnReviewRequest": .bool(toastOnReviewRequest),
            "toastOnReviewDecision": .bool(toastOnReviewDecision),
        ]
    }

    func applyConfig(_ values: [String: ConfigValue]) {
        suppressWrite = true
        defer { suppressWrite = false }
        if let v = values["accounts"]?.stringValue { accounts = v }
        if let v = values["refreshInterval"]?.doubleValue { refreshInterval = v }
        if let v = values["showNotifications"]?.boolValue { showNotifications = v }
        if let v = values["showBarCounts"]?.boolValue { showBarCounts = v }
        if let v = values["toastOnReviewRequest"]?.boolValue { toastOnReviewRequest = v }
        if let v = values["toastOnReviewDecision"]?.boolValue { toastOnReviewDecision = v }
    }

    /// Explicitly configured logins, or nil meaning "all gh accounts".
    var configuredLogins: [String]? {
        let logins = accounts
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter(GitHubParsing.isValidLogin)
        return logins.isEmpty ? nil : logins
    }
}

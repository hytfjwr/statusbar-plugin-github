import Foundation
import StatusBarKit
import SwiftUI
import Testing

@testable import GitHubPlugin

/// Minimal ThemeProvider mirroring the host app's Defaults — lets the real
/// popup render headlessly for mock screenshots.
@MainActor
private final class MockThemeProvider: ThemeProvider {
    var barHeight: CGFloat = 40
    var barMargin: CGFloat = 8
    var barYOffset: CGFloat = 4
    var barCornerRadius: CGFloat = 12
    var widgetSpacing: CGFloat = 6
    var widgetPaddingH: CGFloat = 6
    var memoryGraphColor: Color = Color(hex: 0x34C759)
    var cpuGraphColor: Color = Color(hex: 0x007AFF)
    var greenColor: Color = Color(hex: 0x34C759)
    var yellowColor: Color = Color(hex: 0xFF9F0A)
    var redColor: Color = Color(hex: 0xFF3B30)
    var cyanColor: Color = Color(hex: 0x64D2FF)
    var purpleColor: Color = Color(hex: 0xBF5AF2)
    var accentColor: Color = Color(hex: 0x007AFF)
    var primaryColor: Color = .white
    var secondaryColor: Color = .white.opacity(0.55)
    var tertiaryColor: Color = .white.opacity(0.30)
    var sfIconFont: Font = .system(size: 13, weight: .medium, design: .rounded)
    var labelFont: Font = .system(size: 13, weight: .medium)
    var smallFont: Font = .system(size: 11)
    var monoFont: Font = .system(size: 12, weight: .medium, design: .monospaced)
    var popupLabelFont: Font = .system(size: 13)
    var graphWidth: CGFloat = 30
    var graphHeight: CGFloat = 14
    var graphDataPoints: Int = 50
    var barTintHex: UInt32 = 0x000000
    var barTintOpacity: Double = 0
    var shadowEnabled: Bool = true
    var popupCornerRadius: CGFloat = 10
    var popupPadding: CGFloat = 12
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

@MainActor
private enum MockData {
    static func pr(
        repo: String, number: Int, title: String, account: String,
        draft: Bool = false, minutesAgo: Int, headRef: String? = nil,
        author: String = "", decision: ReviewDecision = .none, check: CheckState = .none
    ) -> GitHubPullRequest {
        GitHubPullRequest(
            id: "\(repo)#\(number)", number: number, title: title,
            url: "https://github.com/\(repo)/pull/\(number)",
            repo: repo, isDraft: draft,
            updatedAt: Date().addingTimeInterval(-Double(minutesAgo) * 60),
            headRef: headRef, author: author,
            reviewDecision: decision, checkState: check, account: account
        )
    }

    static func notification(
        id: String, repo: String, reason: String, title: String,
        type: String, minutesAgo: Int, account: String
    ) -> GitHubNotification {
        GitHubNotification(
            id: id, repo: repo, reason: reason, title: title, type: type,
            webURL: "https://github.com/\(repo)",
            updatedAt: Date().addingTimeInterval(-Double(minutesAgo) * 60),
            account: account
        )
    }

    static var snapshots: [AccountSnapshot] {
        [
            AccountSnapshot(
                login: "hytfjwr",
                myPRs: [
                    pr(repo: "hytfjwr/StatusBar", number: 42,
                       title: "Add per-widget corner radius option",
                       account: "hytfjwr", minutesAgo: 26,
                       headRef: "feat/widget-corner-radius",
                       decision: .approved, check: .success),
                    pr(repo: "hytfjwr/StatusBarKit", number: 35,
                       title: "Popover anchoring fixes for multi-display setups",
                       account: "hytfjwr", draft: true, minutesAgo: 190,
                       headRef: "fix/popover-anchor", check: .pending),
                ],
                reviewPRs: [
                    pr(repo: "acme/payment-service", number: 1287,
                       title: "Migrate checkout flow to new billing API",
                       account: "hytfjwr", minutesAgo: 8,
                       author: "tanaka", check: .success),
                ],
                notifications: [
                    notification(id: "n1", repo: "acme/payment-service",
                                 reason: "review_requested",
                                 title: "Migrate checkout flow to new billing API",
                                 type: "PullRequest", minutesAgo: 8, account: "hytfjwr"),
                    notification(id: "n2", repo: "hytfjwr/StatusBar",
                                 reason: "comment",
                                 title: "Add per-widget corner radius option",
                                 type: "PullRequest", minutesAgo: 33, account: "hytfjwr"),
                ]
            ),
            AccountSnapshot(
                login: "dev-work",
                myPRs: [],
                reviewPRs: [
                    pr(repo: "acme/infra", number: 77,
                       title: "Terraform: add staging RDS instance",
                       account: "dev-work", minutesAgo: 300,
                       author: "yamada", decision: .changesRequested,
                       check: .failure),
                ],
                notifications: [
                    notification(id: "n3", repo: "acme/data-pipeline",
                                 reason: "ci_activity",
                                 title: "CI failed: Backfill job for user events table",
                                 type: "WorkflowRun", minutesAgo: 45, account: "dev-work"),
                ]
            ),
        ]
    }
}

@Suite("Popup snapshot rendering")
struct PopupSnapshotRendering {
    /// Renders the popup with mock data to a PNG for manual inspection.
    /// Not a correctness test — a visual-regression helper.
    @Test @MainActor
    func renderPopupMockToPNG() throws {
        Theme.configure(provider: MockThemeProvider())

        let content = GitHubPopupContent(
            snapshots: MockData.snapshots,
            ghAvailable: true,
            loadError: nil,
            fetching: false,
            lastUpdated: Date(),
            showNotifications: true,
            multiAccount: true,
            sectionOrder: PopupSection.parseOrder("review,mine,notifications"),
            onOpenURL: { _ in },
            onRefresh: {},
            onMoveSection: { _, _ in }
        )

        let view = content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(16)
            .environment(\.colorScheme, .dark)

        // ImageRenderer drops ScrollView content; snapshot through a real
        // NSHostingView. PDF is vector — rasterize at 2x for crisp text.
        let hostingView = NSHostingView(rootView: view)
        let scale: CGFloat = 2
        let fitting = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fitting)
        hostingView.layoutSubtreeIfNeeded()

        // Bitmap sized 2x pixels at 1x point size → cacheDisplay draws at
        // Retina scale (NSHostingView.draw() renders nothing headlessly).
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(fitting.width * scale),
            pixelsHigh: Int(fitting.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            Issue.record("Failed to rasterize popup")
            return
        }
        bitmap.size = fitting
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode PNG")
            return
        }

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("github-popup-mock.png")
        try png.write(to: url)
        print("Wrote \(url.path) (\(Int(fitting.width))x\(Int(fitting.height)) @\(Int(scale))x)")
    }
}

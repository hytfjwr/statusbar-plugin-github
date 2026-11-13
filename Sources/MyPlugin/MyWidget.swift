import StatusBarKit
import SwiftUI

@MainActor
final class MyWidget: StatusBarWidget {
    let id = "my-widget"
    let position: WidgetPosition = .right
    let updateInterval: TimeInterval? = 5
    let sfSymbolName = "puzzlepiece.fill"

    private var text = "Hello"

    func start() {}
    func stop() {}

    func body() -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}

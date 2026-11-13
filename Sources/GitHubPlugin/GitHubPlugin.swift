import StatusBarKit

@MainActor
public struct GitHubPlugin: StatusBarPlugin {
    public let manifest = PluginManifest(
        id: "com.statusbar.github",
        name: "GitHub"
    )

    public let widgets: [any StatusBarWidget]

    public init() {
        widgets = [GitHubWidget()]
    }
}

// MARK: - Plugin Factory

@_cdecl("createStatusBarPlugin")
public func createStatusBarPlugin() -> UnsafeMutableRawPointer {
    let box = PluginBox { GitHubPlugin() }
    return Unmanaged.passRetained(box).toOpaque()
}

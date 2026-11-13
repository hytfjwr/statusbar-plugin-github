import StatusBarKit

@MainActor
public struct MyPlugin: StatusBarPlugin {
    public let manifest = PluginManifest(
        id: "com.example.myplugin",
        name: "My Plugin"
    )

    public let widgets: [any StatusBarWidget]

    public init() {
        widgets = [MyWidget()]
    }
}

// MARK: - Plugin Factory

@_cdecl("createStatusBarPlugin")
public func createStatusBarPlugin() -> UnsafeMutableRawPointer {
    let box = PluginBox { MyPlugin() }
    return Unmanaged.passRetained(box).toOpaque()
}

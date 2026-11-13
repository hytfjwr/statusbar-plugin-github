// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyPlugin",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MyPlugin", type: .dynamic, targets: ["MyPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hytfjwr/StatusBarKit", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MyPlugin",
            dependencies: [
                .product(name: "StatusBarKit", package: "StatusBarKit"),
            ]
        ),
    ]
)

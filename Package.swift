// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GitHubPlugin",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "GitHubPlugin", type: .dynamic, targets: ["GitHubPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hytfjwr/StatusBarKit", from: "1.10.1"),
    ],
    targets: [
        .target(
            name: "GitHubPlugin",
            dependencies: [
                .product(name: "StatusBarKit", package: "StatusBarKit"),
            ]
        ),
        .testTarget(
            name: "GitHubPluginTests",
            dependencies: ["GitHubPlugin"]
        ),
    ]
)

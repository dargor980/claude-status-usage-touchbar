// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "claudeBar",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "claudebar", targets: ["ClaudeBarApp"]),
    ],
    targets: [
        .target(
            name: "ClaudeBarDomain"
        ),
        .target(
            name: "ClaudeBarApplication",
            dependencies: ["ClaudeBarDomain"]
        ),
        .target(
            name: "ClaudeBarInfrastructure",
            dependencies: ["ClaudeBarDomain", "ClaudeBarApplication"]
        ),
        .target(
            name: "ClaudeBarPresentation",
            dependencies: ["ClaudeBarDomain", "ClaudeBarApplication"]
        ),
        .executableTarget(
            name: "ClaudeBarApp",
            dependencies: [
                "ClaudeBarDomain",
                "ClaudeBarApplication",
                "ClaudeBarInfrastructure",
                "ClaudeBarPresentation",
            ]
        ),
        .testTarget(
            name: "ClaudeBarApplicationTests",
            dependencies: ["ClaudeBarApplication", "ClaudeBarDomain"]
        ),
    ]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClaudeTerm",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeTerm",
            dependencies: ["SwiftTerm"],
            path: "ClaudeTerm",
            resources: [
                .copy("Shell/claudeterm-integration.zsh"),
                .copy("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "ClaudeTermTests",
            dependencies: ["ClaudeTerm"],
            path: "ClaudeTermTests"
        )
    ]
)

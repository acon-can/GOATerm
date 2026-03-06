// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GOAT",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "GOAT",
            dependencies: ["SwiftTerm", "Sparkle"],
            path: "GOAT",
            resources: [
                .copy("Shell/goat-integration.zsh"),
                .copy("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "GOATTests",
            dependencies: ["GOAT"],
            path: "GOATTests"
        )
    ]
)

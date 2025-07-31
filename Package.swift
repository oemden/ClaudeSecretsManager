// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClaudeSecretsManager",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "claudesecrets",
            targets: ["ClaudeSecrets"]
        ),
        .executable(
            name: "claudesecrets-cli",
            targets: ["ClaudeSecretsCLI"]
        )
    ],
    targets: [
        .target(
            name: "SharedConstants",
            dependencies: []
        ),
        .executableTarget(
            name: "ClaudeSecrets",
            dependencies: ["SharedConstants"]
        ),
        .executableTarget(
            name: "ClaudeSecretsCLI",
            dependencies: ["SharedConstants"]
        )
    ]
)

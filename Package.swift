// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClaudeAutoConfig",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "ClaudeAutoConfig",
            targets: ["ClaudeAutoConfig"]
        ),
        .executable(
            name: "ClaudeAutoConfigCLI",
            targets: ["ClaudeAutoConfigCLI"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ClaudeAutoConfig",
            dependencies: []
        ),
        .executableTarget(
            name: "ClaudeAutoConfigCLI",
            dependencies: []
        )
    ]
)

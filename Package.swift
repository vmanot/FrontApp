// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "FrontApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "FrontApp",
            targets: [
                "FrontApp"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vmanot/CorePersistence.git", branch: "main"),
        .package(url: "https://github.com/vmanot/NetworkKit.git", branch: "master"),
        .package(url: "https://github.com/vmanot/Swallow.git", branch: "master")
    ],
    targets: [
        .target(
            name: "FrontApp",
            dependencies: [
                "CorePersistence",
                "NetworkKit",
                "Swallow"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "Frontapp",
            dependencies: [
                "FrontApp"
            ],
            path: "Tests"
        )
    ]
)

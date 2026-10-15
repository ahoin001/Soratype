// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LeanTypeEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LeanTypeEngine", targets: ["LeanTypeEngine"]),
    ],
    targets: [
        .target(
            name: "LeanTypeEngine",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "LeanTypeEngineTests",
            dependencies: ["LeanTypeEngine"]
        ),
    ]
)

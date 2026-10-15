// swift-tools-version: 6.2

import PackageDescription

let engineSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "SoratypeEngine",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SoratypeEngine", targets: ["SoratypeEngine"]),
    ],
    targets: [
        .target(
            name: "SoratypeEngine",
            swiftSettings: engineSwiftSettings
        ),
        .testTarget(
            name: "SoratypeEngineTests",
            dependencies: ["SoratypeEngine"],
            swiftSettings: engineSwiftSettings
        ),
    ]
)

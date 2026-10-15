// swift-tools-version: 6.2

import PackageDescription

let lexiconSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "SoratypeLexiconBuilder",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SoratypeLexiconBuilder", targets: ["SoratypeLexiconBuilder"]),
    ],
    dependencies: [
        .package(path: "../SoratypeEngine"),
    ],
    targets: [
        .target(
            name: "SoratypeLexiconBuilder",
            dependencies: ["SoratypeEngine"],
            swiftSettings: lexiconSwiftSettings
        ),
        .testTarget(
            name: "SoratypeLexiconBuilderTests",
            dependencies: ["SoratypeLexiconBuilder", "SoratypeEngine"],
            swiftSettings: lexiconSwiftSettings
        ),
    ]
)

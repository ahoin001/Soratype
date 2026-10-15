// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LeanTypeLexiconBuilder",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LeanTypeLexiconBuilder", targets: ["LeanTypeLexiconBuilder"]),
    ],
    dependencies: [
        .package(path: "../LeanTypeEngine"),
    ],
    targets: [
        .target(
            name: "LeanTypeLexiconBuilder",
            dependencies: ["LeanTypeEngine"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "LeanTypeLexiconBuilderTests",
            dependencies: ["LeanTypeLexiconBuilder", "LeanTypeEngine"]
        ),
    ]
)

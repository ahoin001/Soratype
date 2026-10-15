// swift-tools-version: 6.2

import PackageDescription

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
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "SoratypeLexiconBuilderTests",
            dependencies: ["SoratypeLexiconBuilder", "SoratypeEngine"]
        ),
    ]
)

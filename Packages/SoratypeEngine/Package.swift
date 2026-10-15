// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SoratypeEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SoratypeEngine", targets: ["SoratypeEngine"]),
    ],
    targets: [
        .target(
            name: "SoratypeEngine",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "SoratypeEngineTests",
            dependencies: ["SoratypeEngine"]
        ),
    ]
)

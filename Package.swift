// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Wormhole",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(
            name: "Wormhole",
            targets: ["MMWormhole", "Wormhole"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MMWormhole",
            dependencies: []
        ),
        .target(
            name: "Wormhole",
            dependencies: [
                .target(name: "MMWormhole")
            ]
        ),
    ]
)

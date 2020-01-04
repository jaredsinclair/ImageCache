// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ImageCache",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "ImageCache", targets: ["ImageCache"])
    ],
    dependencies: [
        .package(url: "https://github.com/jaredsinclair/etcetera", .branch("master"))
    ],
    targets: [
        .target(
            name: "ImageCache",
            dependencies: [
                "Etcetera"
            ]),
        .testTarget(name: "ImageCacheTests",
            dependencies: [
                "ImageCache"
            ]),
    ]
)

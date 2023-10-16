// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ImageCache",
    platforms: [
        .iOS("17"), .tvOS("17")
    ],
    products: [
        .library(name: "ImageCache", targets: ["ImageCache"])
    ],
    dependencies: [
        .package(url: "https://github.com/jaredsinclair/etcetera", .branch("concurrency"))
    ],
    targets: [
        .target(
            name: "ImageCache",
            dependencies: [
                "Etcetera"
            ],
            swiftSettings: [ .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"]) ]
        ),
        .testTarget(name: "ImageCacheTests",
            dependencies: [
                "ImageCache"
            ]),
    ]
)

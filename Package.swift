// swift-tools-version:6.0

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
        .package(url: "https://github.com/jaredsinclair/etcetera", .branch("swift6"))
    ],
    targets: [
        .target(
            name: "ImageCache",
            dependencies: [
                .product(name: "Etcetera", package: "Etcetera")
            ],
            swiftSettings: [ .swiftLanguageVersion(.v6) ]
        ),
        .testTarget(name: "ImageCacheTests",
            dependencies: [
                "ImageCache"
            ]),
    ]
)

// swift-tools-version:5.10

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
        .package(url: "https://github.com/jaredsinclair/etcetera", .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
        .target(
            name: "ImageCache",
            dependencies: [
                .product(name: "Etcetera", package: "Etcetera")
            ]
            // Uncomment to enable complete strict concurrency checking. In a
            // future update, it would be handy if this were scriptable in CI:
            // swiftSettings: [ .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"]) ]
        ),
        .testTarget(name: "ImageCacheTests",
            dependencies: [
                "ImageCache"
            ]),
    ]
)

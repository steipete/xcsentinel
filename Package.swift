// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcsentinel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "xcsentinel",
            targets: ["xcsentinel"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "xcsentinel",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "xcsentinelTests",
            dependencies: ["xcsentinel"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
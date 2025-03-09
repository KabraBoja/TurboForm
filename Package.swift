// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TurboForm",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TurboForm", targets: ["TurboForm"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TurboForm",
            dependencies: [],
            path: "src",
            swiftSettings: []
        ),
        .testTarget(
            name: "TurboFormTests",
            dependencies: ["TurboForm"],
            path: "tests"
        )
    ]
)

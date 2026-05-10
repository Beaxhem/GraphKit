// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GraphKit",
            targets: ["GraphKit"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GraphKit",
            resources: [
                .process("Shaders/BarChart.metal"),
                .process("Shaders/LineChart.metal"),
            ]
        ),
        .testTarget(
            name: "GraphKitTests",
            dependencies: ["GraphKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

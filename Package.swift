// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CompArch",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "CompArch",
            targets: ["CompArch"]),
        .library(name: "CompArchTestSupport",
                 targets: ["CompArchTestSupport"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CompArch",
            dependencies: ["CasePaths"]),
        .target(
            name: "CompArchTestSupport",
            dependencies: ["CompArch"]),
        .testTarget(
            name: "CompArchTests",
            dependencies: ["CompArch"]),
    ]
)

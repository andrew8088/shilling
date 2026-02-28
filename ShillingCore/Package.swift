// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ShillingCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ShillingCore",
            targets: ["ShillingCore"]
        ),
        .executable(
            name: "ShillingCLI",
            targets: ["ShillingCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "ShillingCore",
            dependencies: []
        ),
        .executableTarget(
            name: "ShillingCLI",
            dependencies: [
                "ShillingCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "ShillingCoreTests",
            dependencies: ["ShillingCore"]
        ),
    ]
)

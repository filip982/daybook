// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DaybookPlatform",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "DaybookPlatform", targets: ["DaybookPlatform"]),
    ],
    targets: [
        .target(name: "DaybookPlatform"),
        .testTarget(name: "DaybookPlatformTests", dependencies: ["DaybookPlatform"]),
    ]
)

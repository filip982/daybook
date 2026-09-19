// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherFeature",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "WeatherFeature", targets: ["WeatherFeature"]),
    ],
    dependencies: [
        .package(path: "../DaybookPlatform"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.5"),
    ],
    targets: [
        .target(name: "WeatherFeature", dependencies: ["DaybookPlatform"]),
        .testTarget(
            name: "WeatherFeatureTests",
            dependencies: [
                "WeatherFeature",
                "DaybookPlatform",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)

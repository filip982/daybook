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
    ],
    targets: [
        .target(name: "WeatherFeature", dependencies: ["DaybookPlatform"]),
        .testTarget(name: "WeatherFeatureTests", dependencies: ["WeatherFeature", "DaybookPlatform"]),
    ]
)

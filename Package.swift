// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "PPG_framework",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "PPG_framework",
            targets: ["PPG_framework"]),
    ],
    dependencies: [
        // Add your dependencies here if any
    ],
    targets: [
        .target(
            name: "PPG_framework",
            dependencies: [],
            path: "Sources/PPG_framework"),
        .testTarget(
            name: "PPG_frameworkTests",
            dependencies: ["PPG_framework"],
            path: "Tests/PPG_frameworkTests"),
    ]
)

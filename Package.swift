// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "PPG_iOS_SDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Push Notifications SDK
        .library(
            name: "PPG_framework",
            targets: ["PPG_framework"]),
        // In-App Messages SDK
        .library(
            name: "PPG_InAppMessages",
            targets: ["PPG_InAppMessages"]),
        // Live Activities SDK (requires iOS 16.1+)
        .library(
            name: "PPG_LiveActivities",
            targets: ["PPG_LiveActivities"]),
    ],
    dependencies: [
        // Add your dependencies here if any
    ],
    targets: [
        // Push Notifications SDK Target
        .target(
            name: "PPG_framework",
            dependencies: [],
            path: "Sources/PPG_framework"),
        .testTarget(
            name: "PPG_frameworkTests",
            dependencies: ["PPG_framework"],
            path: "Tests/PPG_frameworkTests"),
        
        // In-App Messages SDK Target
        .target(
            name: "PPG_InAppMessages",
            dependencies: [],
            path: "Sources/PPG_InAppMessages",
            resources: [
                .copy("Resources/Fonts")
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .linkedFramework("WebKit", .when(platforms: [.iOS])),
                .linkedFramework("Foundation", .when(platforms: [.iOS]))
            ]),
        .testTarget(
            name: "PPG_InAppMessagesTests",
            dependencies: ["PPG_InAppMessages"],
            path: "Tests/PPG_InAppMessagesTests"),
        
        // Live Activities SDK Target (requires iOS 16.1+, uses @available annotations)
        .target(
            name: "PPG_LiveActivities",
            dependencies: [],
            path: "Sources/PPG_LiveActivities",
            linkerSettings: [
                .linkedFramework("ActivityKit", .when(platforms: [.iOS])),
                .linkedFramework("SwiftUI", .when(platforms: [.iOS])),
                .linkedFramework("WidgetKit", .when(platforms: [.iOS])),
                .linkedFramework("Foundation", .when(platforms: [.iOS]))
            ]),
        .testTarget(
            name: "PPG_LiveActivitiesTests",
            dependencies: ["PPG_LiveActivities"],
            path: "Tests/PPG_LiveActivitiesTests"),
    ]
)

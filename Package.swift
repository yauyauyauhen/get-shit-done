// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GetShitDone",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "GetShitDone",
            path: "GetShitDone",
            exclude: ["Info.plist", "GetShitDone.entitlements", "Assets.xcassets"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("Security"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreMedia"),
            ]
        )
    ]
)

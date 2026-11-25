// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Floqy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Floqy", targets: ["Floqy"])
    ],
    targets: [
        .executableTarget(
            name: "Floqy",
            path: "Sources/Floqy",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Carbon"),
                .linkedFramework("EventKit")
            ]
        )
    ]
)

// swift-tools-version: 5.9
// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "VauchiPlatform",
    platforms: [.macOS(.v14), .iOS(.v16)],
    products: [
        .library(name: "VauchiPlatform", targets: ["VauchiPlatform", "VauchiPlatformFFI"]),
    ],
    targets: [
        .binaryTarget(
            name: "VauchiPlatformFFI",
            path: "VauchiPlatformFFI.xcframework"
        ),
        .target(
            name: "VauchiPlatform",
            dependencies: ["VauchiPlatformFFI"],
            path: "Sources/VauchiPlatform"
        ),
    ]
)

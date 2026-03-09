// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VauchiMobile",
    platforms: [.macOS(.v14), .iOS(.v16)],
    products: [
        .library(name: "VauchiMobile", targets: ["VauchiMobile", "VauchiMobileFFI"]),
    ],
    targets: [
        .binaryTarget(
            name: "VauchiMobileFFI",
            path: "VauchiMobileFFI.xcframework"
        ),
        .target(
            name: "VauchiMobile",
            dependencies: ["VauchiMobileFFI"],
            path: "Sources/VauchiMobile"
        ),
    ]
)

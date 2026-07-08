// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VauchiMacOS",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://gitlab.com/vauchi/vauchi-platform-swift.git",
            from: "0.52.5"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Vauchi",
            dependencies: [
                .product(name: "VauchiPlatform", package: "vauchi-platform-swift"),
                .product(name: "VauchiHardware", package: "vauchi-platform-swift"),
                .product(name: "CoreUIModels", package: "vauchi-platform-swift"),
            ],
            path: "Vauchi"
        ),
    ]
)

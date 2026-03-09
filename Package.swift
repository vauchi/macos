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
            url: "https://gitlab.com/vauchi/vauchi-mobile-swift.git",
            from: "0.4.1-dev.1"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Vauchi",
            dependencies: [
                .product(name: "VauchiMobile", package: "vauchi-mobile-swift"),
            ],
            path: "Vauchi"
        ),
    ]
)

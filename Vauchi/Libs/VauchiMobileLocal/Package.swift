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

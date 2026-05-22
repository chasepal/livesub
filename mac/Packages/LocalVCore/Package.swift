// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalVCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "LocalVCore",
            targets: ["LocalVCore"]
        ),
        .executable(
            name: "LocalVCoreSmokeTests",
            targets: ["LocalVCoreSmokeTests"]
        )
    ],
    targets: [
        .target(
            name: "LocalVCore"
        ),
        .executableTarget(
            name: "LocalVCoreSmokeTests",
            dependencies: ["LocalVCore"]
        )
    ]
)


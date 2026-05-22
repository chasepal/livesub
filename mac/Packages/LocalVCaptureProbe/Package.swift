// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalVCaptureProbe",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "LocalVCaptureProbe",
            targets: ["LocalVCaptureProbe"]
        )
    ],
    dependencies: [
        .package(path: "../LocalVCore")
    ],
    targets: [
        .executableTarget(
            name: "LocalVCaptureProbe",
            dependencies: ["LocalVCore"],
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreMedia")
            ]
        )
    ]
)


// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalVAppShell",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "LocalVAppShell",
            targets: ["LocalVAppShell"]
        )
    ],
    dependencies: [
        .package(path: "../LocalVCore"),
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "LocalVAppShell",
            dependencies: [
                "LocalVCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreMedia")
            ]
        )
    ]
)

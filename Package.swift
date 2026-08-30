// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpsNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OpsNotchCore", targets: ["OpsNotchCore"]),
        .executable(name: "OpsNotch", targets: ["OpsNotchApp"])
    ],
    targets: [
        .target(
            name: "OpsNotchCore",
            path: "Sources/OpsNotchCore"
        ),
        .executableTarget(
            name: "OpsNotchApp",
            dependencies: ["OpsNotchCore"],
            path: "Sources/OpsNotchApp"
        ),
        .testTarget(
            name: "OpsNotchCoreTests",
            dependencies: ["OpsNotchCore"],
            path: "Tests/OpsNotchCoreTests"
        )
    ]
)

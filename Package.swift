// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpsNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OpsNotchCore", targets: ["OpsNotchCore"]),
        .executable(name: "OpsNotch", targets: ["OpsNotchApp"]),
        .executable(name: "FinderSpaceDemo", targets: ["FinderSpaceDemo"])
    ],
    targets: [
        .target(
            name: "OpsNotchCore",
            path: "Sources/OpsNotchCore"
        ),
        .target(
            name: "OpsNotchPrivateInterop",
            path: "Sources/OpsNotchPrivateInterop",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "OpsNotchApp",
            dependencies: ["OpsNotchCore", "OpsNotchPrivateInterop"],
            path: "Sources/OpsNotchApp"
        ),
        .target(
            name: "FinderSpaceDemoBridge",
            dependencies: ["OpsNotchPrivateInterop"],
            path: "Demos/FinderSpaceDemo/Bridge",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .executableTarget(
            name: "FinderSpaceDemo",
            dependencies: ["FinderSpaceDemoBridge"],
            path: "Demos/FinderSpaceDemo/App"
        ),
        .testTarget(
            name: "OpsNotchCoreTests",
            dependencies: ["OpsNotchCore"],
            path: "Tests/OpsNotchCoreTests"
        ),
        .testTarget(
            name: "FinderSpaceDemoTests",
            dependencies: ["FinderSpaceDemo"],
            path: "Demos/FinderSpaceDemo/Tests"
        )
    ]
)

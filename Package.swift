// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ManoScrollApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ManoScrollApp", targets: ["ManoScrollApp"])
    ],
    targets: [
        .executableTarget(
            name: "ManoScrollApp",
            path: "ManoScrollApp",
            exclude: ["Info.plist", "ManoScrollApp.entitlements"]
        ),
        .testTarget(
            name: "ManoScrollAppTests",
            dependencies: ["ManoScrollApp"],
            path: "Tests/ManoScrollAppTests"
        ),
        .testTarget(
            name: "ManoScrollAppUITests",
            dependencies: ["ManoScrollApp"],
            path: "Tests/ManoScrollAppUITests"
        )
    ]
)

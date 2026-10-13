// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sundial",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SundialCore", targets: ["SundialCore"]),
        .executable(name: "SundialApp", targets: ["SundialApp"]),
    ],
    targets: [
        .target(name: "SundialCore"),
        .executableTarget(
            name: "SundialApp",
            dependencies: ["SundialCore"]
        ),
        .testTarget(
            name: "SundialCoreTests",
            dependencies: ["SundialCore"]
        ),
    ]
)

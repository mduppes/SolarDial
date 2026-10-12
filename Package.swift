// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flux",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FluxCore", targets: ["FluxCore"]),
        .executable(name: "FluxApp", targets: ["FluxApp"]),
    ],
    targets: [
        .target(name: "FluxCore"),
        .executableTarget(
            name: "FluxApp",
            dependencies: ["FluxCore"]
        ),
        .testTarget(
            name: "FluxCoreTests",
            dependencies: ["FluxCore"]
        ),
    ]
)

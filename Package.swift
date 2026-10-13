// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SolarDial",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SolarDialCore", targets: ["SolarDialCore"]),
        .executable(name: "SolarDialApp", targets: ["SolarDialApp"]),
    ],
    targets: [
        .target(name: "SolarDialCore"),
        .executableTarget(
            name: "SolarDialApp",
            dependencies: ["SolarDialCore"]
        ),
        .testTarget(
            name: "SolarDialCoreTests",
            dependencies: ["SolarDialCore"]
        ),
    ]
)

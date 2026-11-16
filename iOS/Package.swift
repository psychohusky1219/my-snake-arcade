// swift-tools-version: 5.9
import PackageDescription

// This package tests the exact game engine used by the native iOS target.
// Open MySnake.xcodeproj, not this Package.swift, to build the iPhone app.
let package = Package(
    name: "MySnakeCoreChecks",
    products: [.library(name: "SnakeCore", targets: ["SnakeCore"])],
    targets: [
        .target(name: "SnakeCore", path: "MySnake/Core"),
        .testTarget(name: "SnakeCoreTests", dependencies: ["SnakeCore"], path: "Tests/SnakeCoreTests")
    ]
)

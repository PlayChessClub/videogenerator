// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipForgeCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v11),
    ],
    products: [
        .library(name: "ClipForgeCore", targets: ["ClipForgeCore"]),
    ],
    targets: [
        .target(name: "ClipForgeCore", path: "Sources/ClipForgeCore"),
    ]
)

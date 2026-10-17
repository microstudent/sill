// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sill",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Sill", targets: ["Sill"])],
    targets: [
        .target(name: "SillCore"),
        .executableTarget(name: "Sill", dependencies: ["SillCore"]),
        .testTarget(name: "SillCoreTests", dependencies: ["SillCore"])
    ],
    swiftLanguageModes: [.v5]
)

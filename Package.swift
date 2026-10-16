// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TensorTycoon",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "TensorTycoon",
            path: "Sources/TensorTycoon",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

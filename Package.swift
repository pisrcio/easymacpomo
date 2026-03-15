// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EasyMacPomo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EasyMacPomo",
            path: "Sources/EasyMacPomo"
        )
    ]
)

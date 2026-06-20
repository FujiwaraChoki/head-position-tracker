// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PostureTimer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PostureTimer",
            path: "Sources/PostureTimer"
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlanceID",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "GlanceID",
            targets: ["GlanceID"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GlanceID",
            path: "Sources/GlanceID"
        )
    ]
)

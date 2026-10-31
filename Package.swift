// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tuck",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Tuck",
            path: "Sources/Tuck",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-dead_strip"])]
        ),
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoTranscribe",
    platforms: [
        .macOS(.v14) // Target macOS 14+ or 15+ (Sequoia) as requested, using 14 minimum for Observable macro support
    ],
    products: [
        .executable(name: "VideoTranscribe", targets: ["VideoTranscribe"])
    ],
    targets: [
        .executableTarget(
            name: "VideoTranscribe",
            path: "VideoTranscribe"
        )
    ]
)

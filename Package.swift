// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexMeterMini",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CodexMeter", targets: ["CodexMeter"])
    ],
    targets: [
        .executableTarget(
            name: "CodexMeter",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "CodexMeterTests", dependencies: ["CodexMeter"])
    ]
)

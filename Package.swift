// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TorahInspectorKit",
    defaultLocalization: "en",
    platforms: [.iOS("17.0"), .macOS("14.0")],
    products: [
        .library(name: "TorahInspectorCore", targets: ["TorahInspectorCore"]),
        .library(name: "TorahInspectorUI", targets: ["TorahInspectorUI"])
    ],
    targets: [
        .target(name: "TorahInspectorCore"),
        .target(
            name: "TorahInspectorUI",
            dependencies: ["TorahInspectorCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TorahInspectorCoreTests",
            dependencies: ["TorahInspectorCore"]
        ),
        .testTarget(
            name: "TorahInspectorUITests",
            dependencies: ["TorahInspectorUI"]
        )
    ]
)

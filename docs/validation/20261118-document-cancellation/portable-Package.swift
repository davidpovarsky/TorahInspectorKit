// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "TorahInspectorDocumentCancellationProof",
    products: [.library(name: "TorahInspectorCore", targets: ["TorahInspectorCore"])],
    targets: [
        .target(name: "TorahInspectorCore"),
        .testTarget(name: "TorahInspectorCoreTests", dependencies: ["TorahInspectorCore"])
    ]
)

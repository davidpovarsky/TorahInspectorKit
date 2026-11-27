// swift-tools-version: 6.0
import PackageDescription

// Exact new production helper and exact new tests only. This component does
// not compile the SwiftUI module, the full Kit package, or either host app.
let package = Package(
    name: "TorahReaderLifetimeComponent",
    products: [.library(name: "TorahInspectorUI", targets: ["TorahInspectorUI"])],
    targets: [
        .target(name: "TorahInspectorUI"),
        .testTarget(name: "TorahInspectorUITests", dependencies: ["TorahInspectorUI"])
    ]
)

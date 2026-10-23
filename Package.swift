// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacHandle",
    platforms: [.macOS(.v14)],
    products: [.library(name: "MacHandleFoundation", targets: ["MacHandleFoundation"])],
    targets: [
        .target(name: "MacHandleFoundation"),
        .testTarget(
            name: "MacHandleFoundationTests",
            dependencies: ["MacHandleFoundation"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

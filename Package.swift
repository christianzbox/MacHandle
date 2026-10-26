// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacHandle",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MacHandleFoundation", targets: ["MacHandleFoundation"]),
        .library(name: "CoreDomain", targets: ["CoreDomain"]),
        .library(name: "PermissionEngine", targets: ["PermissionEngine"]),
    ],
    targets: [
        .target(name: "MacHandleFoundation"),
        .target(name: "CoreDomain"),
        .testTarget(name: "CoreDomainTests", dependencies: ["CoreDomain"]),
        .target(name: "PermissionEngine", dependencies: ["CoreDomain"]),
        .testTarget(name: "PermissionEngineTests", dependencies: ["PermissionEngine"]),
        .testTarget(
            name: "MacHandleFoundationTests",
            dependencies: ["MacHandleFoundation"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

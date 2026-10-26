// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacHandle",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppleCalendarProvider", targets: ["AppleCalendarProvider"]),
        .library(name: "MacHandleFoundation", targets: ["MacHandleFoundation"]),
        .library(name: "CoreDomain", targets: ["CoreDomain"]),
        .library(name: "PermissionEngine", targets: ["PermissionEngine"]),
        .library(name: "MacHandleApplication", targets: ["MacHandleApplication"]),
    ],
    targets: [
        .target(name: "AppleCalendarProvider", dependencies: ["CoreDomain"]),
        .testTarget(name: "AppleCalendarProviderTests", dependencies: ["AppleCalendarProvider"]),
        .target(name: "MacHandleFoundation"),
        .target(name: "CoreDomain"),
        .testTarget(name: "CoreDomainTests", dependencies: ["CoreDomain"]),
        .target(name: "PermissionEngine", dependencies: ["CoreDomain"]),
        .testTarget(name: "PermissionEngineTests", dependencies: ["PermissionEngine"]),
        .target(name: "MacHandleApplication", dependencies: ["CoreDomain", "PermissionEngine"]),
        .testTarget(name: "MacHandleApplicationTests", dependencies: ["MacHandleApplication"]),
        .testTarget(
            name: "MacHandleFoundationTests",
            dependencies: ["MacHandleFoundation"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

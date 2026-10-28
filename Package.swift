// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacHandle",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "machandle-mcp", targets: ["MacHandleMCP"]),
        .library(name: "SyncExecution", targets: ["SyncExecution"]),
        .library(name: "SyncPlanning", targets: ["SyncPlanning"]),
        .library(name: "SyncPersistence", targets: ["SyncPersistence"]),
        .library(name: "GoogleAuthorization", targets: ["GoogleAuthorization"]),
        .library(name: "AppleCalendarProvider", targets: ["AppleCalendarProvider"]),
        .library(name: "MacHandleFoundation", targets: ["MacHandleFoundation"]),
        .library(name: "CoreDomain", targets: ["CoreDomain"]),
        .library(name: "PermissionEngine", targets: ["PermissionEngine"]),
        .library(name: "MacHandleApplication", targets: ["MacHandleApplication"]),
    ],
    targets: [
        .target(name: "MCPServer"),
        .executableTarget(name: "MacHandleMCP", dependencies: ["MCPServer"]),
        .testTarget(name: "MCPServerTests", dependencies: ["MCPServer"]),
        .target(
            name: "SyncExecution",
            dependencies: ["CoreDomain", "SyncPlanning", "SyncPersistence", "GoogleAuthorization"]),
        .testTarget(
            name: "SyncExecutionTests", dependencies: ["SyncExecution", "AppleCalendarProvider"]),
        .target(name: "SyncPlanning", dependencies: ["CoreDomain"]),
        .testTarget(name: "SyncPlanningTests", dependencies: ["SyncPlanning"]),
        .target(name: "SyncPersistence", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "SyncPersistenceTests", dependencies: ["SyncPersistence"]),
        .target(name: "GoogleAuthorization"),
        .testTarget(name: "GoogleAuthorizationTests", dependencies: ["GoogleAuthorization"]),
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

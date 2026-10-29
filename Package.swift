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
        .target(
            name: "ReminderMutations",
            dependencies: ["CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence"]),
        .testTarget(
            name: "ReminderMutationsTests", dependencies: ["ReminderMutations", "PermissionEngine"]),
        .target(
            name: "CalendarMutations",
            dependencies: ["CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence"]),
        .testTarget(
            name: "CalendarMutationsTests", dependencies: ["CalendarMutations", "PermissionEngine"]),
        .target(name: "ActionApprovals", dependencies: ["CoreDomain", "PermissionEngine"]),
        .testTarget(
            name: "ActionApprovalsTests", dependencies: ["ActionApprovals", "MCPConnections"]),
        .target(
            name: "MCPRemindersAdapter",
            dependencies: [
                "MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections", "ActionApprovals",
            ]),
        .testTarget(name: "MCPRemindersAdapterTests", dependencies: ["MCPRemindersAdapter"]),
        .target(name: "MCPServer"),
        .target(name: "MCPConnections", dependencies: ["CoreDomain", "PermissionEngine"]),
        .testTarget(
            name: "MCPConnectionsTests", dependencies: ["MCPConnections", "MCPCalendarAdapter"]),
        .target(
            name: "MCPCalendarAdapter",
            dependencies: ["MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections"]),
        .testTarget(name: "MCPCalendarAdapterTests", dependencies: ["MCPCalendarAdapter"]),
        .executableTarget(
            name: "MacHandleMCP",
            dependencies: ["MCPServer", "MCPCalendarAdapter", "MCPRemindersAdapter"]),
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
        .target(
            name: "MacHandleApplication",
            dependencies: ["CoreDomain", "PermissionEngine", "ActionApprovals"]),
        .testTarget(name: "MacHandleApplicationTests", dependencies: ["MacHandleApplication"]),
        .testTarget(
            name: "MacHandleFoundationTests",
            dependencies: ["MacHandleFoundation"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

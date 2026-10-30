// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacHandle",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppleContactsProvider", targets: ["AppleContactsProvider"]),
        .executable(name: "machandle-mcp", targets: ["MacHandleMCP"]),
        .executable(name: "machandle-local-mcp", targets: ["MacHandleLocalMCP"]),
        .executable(name: "MacHandlePrivateReminders", targets: ["MacHandlePrivateReminders"]),
        .executable(name: "MacHandlePrivateSample", targets: ["MacHandlePrivateSample"]),
        .executable(name: "machandle-bridge-probe", targets: ["BridgeProbe"]),
        .executable(name: "machandle-sample-broker", targets: ["SampleBroker"]),
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
        .target(name: "ReminderMCPContract", dependencies: ["MCPServer"]),
        .executableTarget(
            name: "MacHandleLocalMCP",
            dependencies: ["LocalBridgeTransport", "MCPServer", "ReminderMCPContract"]),
        .executableTarget(
            name: "MacHandlePrivateReminders",
            dependencies: ["MacHandleApplication", "AppleCalendarProvider"]),
        .executableTarget(name: "MacHandlePrivateSample", dependencies: ["MacHandleApplication"]),
        .target(name: "LocalBridgeTransport"),
        .testTarget(name: "LocalBridgeTransportTests", dependencies: ["LocalBridgeTransport"]),
        .executableTarget(name: "BridgeProbe", dependencies: ["LocalBridgeTransport"]),
        .executableTarget(
            name: "SampleBroker", dependencies: ["NativeMCPBridge", "LocalBridgeTransport"]),
        .target(
            name: "NativeMCPBridge",
            dependencies: [
                "CoreDomain", "PermissionEngine", "MCPConnections", "MCPServer",
                "MCPRemindersAdapter", "LocalBridgeTransport",
            ]),
        .testTarget(name: "NativeMCPBridgeTests", dependencies: ["NativeMCPBridge"]),
        .target(
            name: "ContactMutations",
            dependencies: ["CoreDomain", "PermissionEngine", "ActionApprovals", "SyncPersistence"]),
        .testTarget(name: "ContactMutationsTests", dependencies: ["ContactMutations"]),
        .target(
            name: "MCPContactsAdapter",
            dependencies: [
                "MCPServer", "CoreDomain", "PermissionEngine", "MCPConnections", "ActionApprovals",
            ]),
        .testTarget(name: "MCPContactsAdapterTests", dependencies: ["MCPContactsAdapter"]),
        .target(name: "AppleContactsProvider", dependencies: ["CoreDomain"]),
        .testTarget(name: "AppleContactsProviderTests", dependencies: ["AppleContactsProvider"]),
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
                "ReminderMCPContract",
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
            dependencies: [
                "MCPServer", "MCPCalendarAdapter", "MCPRemindersAdapter", "MCPContactsAdapter",
            ]),
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
            dependencies: ["CoreDomain", "PermissionEngine", "ActionApprovals", "NativeMCPBridge"]),
        .testTarget(name: "MacHandleApplicationTests", dependencies: ["MacHandleApplication"]),
        .testTarget(
            name: "MacHandleFoundationTests",
            dependencies: ["MacHandleFoundation"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

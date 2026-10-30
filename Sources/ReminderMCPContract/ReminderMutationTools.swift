import MCPServer

package enum ReminderMutationTools {
    package static func make(
        privateSession: Bool = false,
        execute: @escaping @Sendable (String, [String: MCPJSON]) async throws -> MCPToolResult
    ) -> [MCPTool] {
        [
            MCPTool(
                name: "propose_reminder_change",
                description: privateSession
                    ? "Propose one sample Reminder change for exact native review. Use a listId from discovery for create or reminderId from search otherwise. No approval or execution here. No real data, alarms, recurrence or list moves."
                    : "Prepare a Reminder create/update/setDue/complete/uncomplete/delete for local review. Does not execute or approve. This synthetic helper uses a separate sample connection: targetId sample-list for create or sample-reminder otherwise. No real data. Empty notes clears notes; empty dueDate clears due. No alarms, recurrence or list moves.",
                parameters: [
                    .init("operation", kind: .string(maximum: 10)),
                    .init("targetId", kind: .string(maximum: 36)),
                    .init("title", kind: .string(maximum: 512), required: false),
                    .init("notes", kind: .string(maximum: 4096), required: false),
                    .init("dueDate", kind: .string(maximum: 10), required: false),
                    .init("dueTime", kind: .string(maximum: 8), required: false),
                    .init("timeZone", kind: .string(maximum: 128), required: false),
                ],
                outputSchema: ReminderReadSchema.object([
                    "actionId": ReminderReadSchema.string,
                    "status": ReminderReadSchema.choice(["pendingLocalApproval"]),
                ]),
                execute: { try await execute("propose_reminder_change", $0) }),
            MCPTool(
                name: "commit_reminder_change",
                description: privateSession
                    ? "Commit one action after exact native approval. An action ID is not approval. Never retry unknown outcomes. No real data."
                    : "Execute exactly one previously locally confirmed Reminder action. An action ID is not approval. The standalone synthetic helper has no native approval channel, so its proposals cannot execute. Never retry an unknown result.",
                parameters: [.init("actionId", kind: .string(maximum: 36))],
                outputSchema: ReminderReadSchema.object([
                    "status": ReminderReadSchema.choice([
                        "notApproved", "applied", "notApplied", "unknown",
                    ])
                ]),
                execute: { try await execute("commit_reminder_change", $0) }),
        ]
    }
}

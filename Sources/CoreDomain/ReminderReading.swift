/// Requested fields are explicit; recurrence reports presence only, never synthesized occurrences.
public enum ReminderReadField: Hashable, Sendable { case title, notes, due, completion, recurrence }
public enum ReminderRecurrence: Hashable, Sendable { case notRecurring, recurring }

public struct ReminderReadRequest: Hashable, Sendable {
    public let lists: Set<ReminderListReference>
    public let item: ReminderReference?
    public init(lists: Set<ReminderListReference>, item: ReminderReference? = nil) throws {
        guard !lists.isEmpty, lists.count <= 32, item == nil || lists == [item!.list] else {
            throw ProviderFailure.invalidData
        }
        self.lists = lists
        self.item = item
    }
}
public struct ReminderSnapshot: Sendable {
    public static let maximumItems = 1000
    public let coverage: ReminderReadRequest
    public let reminders: [Reminder]
    public let observation: ObservationState
    public init(coverage: ReminderReadRequest, reminders: [Reminder], observation: ObservationState)
        throws
    {
        guard reminders.count <= Self.maximumItems,
            Set(reminders.map(\.id)).count == reminders.count,
            reminders.allSatisfy({
                coverage.lists.contains($0.id.list)
                    && (coverage.item == nil || $0.id == coverage.item)
            })
        else { throw ProviderFailure.invalidData }
        self.coverage = coverage
        self.reminders = reminders
        self.observation = observation
    }
}
public protocol ReminderDiscovering: Sendable {
    func authorization() async -> OSAuthorization
    func requestAccess() async -> OSAuthorization
    func discoverReminderLists() async -> ProviderReadResult<ResourceDiscovery<ReminderList>>
    func changes() async -> AsyncStream<Void>
}
public protocol ReminderReading: Sendable {
    func readReminders(_ request: ReminderReadRequest, fields: Set<ReminderReadField>) async
        -> ProviderReadResult<ReminderSnapshot>
}

import CoreDomain
import Foundation
import Testing

// All identities/content here are synthetic. No provider, clock, permission, or account access.
private func instant(_ seconds: Double) throws -> Instant {
    try Instant(Date(timeIntervalSince1970: seconds))
}

private func interval(_ start: Double = 0, _ end: Double = 100) throws -> InstantInterval {
    try InstantInterval(start: instant(start), end: instant(end))
}

private func account(
    provider: String = "synthetic-provider", store: String = "synthetic-store",
    id: String = "synthetic-account"
) throws -> AccountReference {
    try AccountReference(
        provider: ProviderID(provider), store: StoreID(store), account: AccountID(id))
}

private func calendar(_ id: String = "synthetic-calendar") throws -> CalendarReference {
    try CalendarReference(account: account(), localID: DomainID(id))
}

private func reference(anchor: RecurrenceAnchor = .notRecurring) throws -> OccurrenceReference {
    try OccurrenceReference(
        calendar: calendar(), item: EventID("synthetic-item"), originalAnchor: anchor)
}

private func occurrence(
    id: OccurrenceReference? = nil, start: Double = 10, end: Double = 20
) throws -> CalendarOccurrence {
    try CalendarOccurrence(
        id: id ?? reference(), time: .timed(interval(start, end), timeZone: TimeZoneID("UTC")),
        occupancy: .busy, status: .active, title: .value("Synthetic event")
    )
}

private func request() throws -> CalendarReadRequest {
    try CalendarReadRequest(calendars: [calendar()], window: interval())
}

private func observation(_ completeness: ReadCompleteness = .complete) throws -> ObservationState {
    try ObservationState(observedAt: instant(100), completeness: completeness)
}

@Test func identifiersPreserveNamespaceAndOpaqueSpelling() throws {
    let localID = try DomainID<CalendarTag>("same-local-id")
    let baseline = try CalendarReference(account: account(), localID: localID)
    let references: Set<CalendarReference> = try [
        baseline,
        CalendarReference(account: account(provider: "other-provider"), localID: localID),
        CalendarReference(account: account(store: "other-store"), localID: localID),
        CalendarReference(account: account(id: "other-account"), localID: localID),
    ]
    #expect(references.count == 4)
    #expect(try EventID("ID") != EventID("id"))
    #expect(try EventID(" id ").rawValue == " id ")
    #expect(throws: DomainValidationError.emptyIdentifier) { try EventID(" \n ") }
    #expect(throws: DomainValidationError.emptyIdentifier) { try EventID("") }
}

@Test func connectionsStartDisabledWithoutCredentials() throws {
    let connection = try Connection(id: ConnectionID("synthetic-connection"), kind: .googleSync)
    #expect(connection.state == .disabled)
    #expect(connection.credential == nil)
    #expect(ConnectionState.disabled != .revoked)
    #expect(OSAuthorization.writeOnly != .fullAccess)
    #expect(OSAuthorization.unknown != .denied)
}

@Test func intervalsAreFiniteNonemptyAndHalfOpen() throws {
    #expect(throws: DomainValidationError.invalidInstant) { try instant(.nan) }
    #expect(throws: DomainValidationError.invalidInstant) { try instant(.infinity) }
    #expect(throws: DomainValidationError.invalidInterval) { try interval(1, 1) }
    #expect(throws: DomainValidationError.invalidInterval) { try interval(2, 1) }
    let window = try interval(10, 20)
    #expect(try window.contains(instant(10)))
    #expect(try !window.contains(instant(20)))
    #expect(try !window.overlaps(interval(20, 30)))
    #expect(try window.overlaps(interval(19, 30)))
    #expect(try window.contains(interval(10, 20)))
    #expect(try !window.contains(interval(9, 20)))
}

@Test func civilDatesRejectNormalizationAndPreserveExclusiveEnd() throws {
    #expect(throws: DomainValidationError.invalidDate) {
        try LocalDate(year: 1900, month: 2, day: 29)
    }
    #expect(throws: DomainValidationError.invalidDate) {
        try LocalDate(year: 2026, month: 4, day: 31)
    }
    #expect(throws: DomainValidationError.invalidDate) { try LocalDate(year: 0, month: 1, day: 1) }
    #expect(throws: DomainValidationError.invalidDate) {
        try LocalDate(year: 2026, month: 13, day: 1)
    }
    let leap = try LocalDate(year: 2000, month: 2, day: 29)
    let next = try LocalDate(year: 2000, month: 3, day: 1)
    #expect(leap < next)
    let days = try LocalDateInterval(start: leap, end: next)
    #expect(days.end == next)
    #expect(throws: DomainValidationError.invalidInterval) {
        try LocalDateInterval(start: leap, end: leap)
    }
    #expect(throws: DomainValidationError.invalidInterval) {
        try LocalDateInterval(start: next, end: leap)
    }
}

@Test func allDayValuesRetainCivilDatesAcrossDST() throws {
    let start = try LocalDate(year: 2026, month: 3, day: 8)
    let end = try LocalDate(year: 2026, month: 3, day: 9)
    let dates = try LocalDateInterval(start: start, end: end)
    let zone = try TimeZoneID("America/New_York")
    let value = EventTime.allDay(dates, timeZone: zone)
    guard case .allDay(let storedDates, let storedZone) = value else {
        Issue.record("All-day value became an instant interval")
        return
    }
    #expect(storedDates == dates)
    #expect(storedZone == zone)
    #expect(throws: DomainValidationError.invalidTimeZone) { try TimeZoneID("Synthetic/Invalid") }
    // No conversion to midnight or assumption of 86,400 seconds; provider DST tests are later.
}

@Test func movedOccurrenceKeepsOriginalAnchorSeparateFromCurrentTime() throws {
    let original = try reference(anchor: .timed(instant(10)))
    let before = try occurrence(id: original)
    let moved = try occurrence(id: original, start: 50, end: 60)
    #expect(before.id == moved.id)
    #expect(before.time != moved.time)
    #expect(Set([before.id, moved.id]).count == 1)
    #expect(try reference(anchor: .unknown) != reference(anchor: .notRecurring))
    #expect(try original != reference(anchor: .timed(instant(50))))
    #expect(try original != reference(anchor: .allDay(LocalDate(year: 2026, month: 1, day: 1))))
}

@Test func emptyPartialFailedAndStaleObservationsRemainDistinct() throws {
    let coverage = try request()
    let empty = try CalendarSnapshot(
        coverage: coverage, occurrences: [], observation: observation())
    let partial = try CalendarSnapshot(
        coverage: coverage, occurrences: [], observation: observation(.partial(.morePages)))
    let unknown = try CalendarSnapshot(
        coverage: coverage, occurrences: [], observation: observation(.unknown))
    #expect(empty != partial)
    #expect(empty != unknown)
    #expect(empty.observation.freshness == .unknown)
    let cached = try ObservationState(
        observedAt: instant(100), completeness: .complete, freshness: .localCache)
    #expect(cached != empty.observation)
    let failed: ProviderReadResult<CalendarSnapshot> = .failed(.unavailable)
    guard case .failed(.unavailable) = failed else {
        Issue.record("Unavailable read became an empty success")
        return
    }
    let interrupted = try observation(.partial(.interrupted(.revoked)))
    #expect(interrupted.completeness != .complete)
}

@Test func calendarReadsRejectImplicitAllAndOutOfScopeItems() throws {
    #expect(throws: DomainValidationError.emptySelection) {
        try CalendarReadRequest(calendars: [], window: interval())
    }
    let other = try OccurrenceReference(
        calendar: calendar("other-calendar"), item: EventID("synthetic-item"),
        originalAnchor: .notRecurring)
    #expect(throws: DomainValidationError.resourceOutsideSelection) {
        try CalendarSnapshot(
            coverage: request(), occurrences: [occurrence(id: other)], observation: observation())
    }
    #expect(throws: DomainValidationError.intervalOutsideCoverage) {
        try CalendarSnapshot(
            coverage: request(), occurrences: [occurrence(start: 100, end: 110)],
            observation: observation())
    }
    // An event spanning the query boundary is relevant and must not be lost.
    let spanning = try CalendarSnapshot(
        coverage: request(), occurrences: [occurrence(start: -10, end: 10)],
        observation: observation())
    #expect(spanning.occurrences.count == 1)
}

@Test func availabilityIsBoundedAndPreservesUncertainty() throws {
    let block = try AvailabilityBlock(interval: interval(10, 20), occupancy: .unknown)
    let snapshot = try AvailabilitySnapshot(
        coverage: request(), blocks: [block], observation: observation(.partial(.providerLimit)))
    #expect(snapshot.blocks.first?.occupancy == .unknown)
    #expect(snapshot.observation.completeness != .complete)
    #expect(throws: DomainValidationError.intervalOutsideCoverage) {
        try AvailabilitySnapshot(
            coverage: request(),
            blocks: [AvailabilityBlock(interval: interval(90, 110), occupancy: .busy)],
            observation: observation())
    }
}

@Test func reminderDueDatesDoNotImplyAlarmsOrCompletionInstants() throws {
    let date = try LocalDate(year: 2026, month: 11, day: 1)
    let time = try LocalTime(hour: 1, minute: 30)
    let dateOnly = ReminderDue.date(date)
    let floating = ReminderDue.localDateTime(date, time, timeZone: nil)
    let zoned = try ReminderDue.localDateTime(date, time, timeZone: TimeZoneID("America/New_York"))
    #expect(dateOnly != floating)
    #expect(floating != zoned)
    #expect(ReminderCompletion.incomplete != .completed(at: nil))
    #expect(throws: DomainValidationError.invalidTime) { try LocalTime(hour: 24, minute: 0) }
    #expect(throws: DomainValidationError.invalidTime) { try LocalTime(hour: 1, minute: 60) }
    #expect(throws: DomainValidationError.invalidTime) {
        try LocalTime(hour: 1, minute: 0, second: -1)
    }
}

@Test func contactFieldsDistinguishOmissionDenialAndFetchedEmpty() throws {
    let id = try ContactReference.unified(
        provider: ProviderID("synthetic-provider"), store: StoreID("synthetic-store"),
        item: ContactID("synthetic-contact"))
    let unfetched = Contact(id: id)
    let denied = Contact(id: id, emailAddresses: .notAuthorized)
    let empty = Contact(id: id, emailAddresses: .value([]), notes: .value(nil))
    #expect(unfetched != denied)
    #expect(unfetched != empty)
    #expect(denied != empty)
    #expect(empty.phoneNumbers == .notFetched)
    #expect(empty.linkedRecords == .notFetched)
    #expect(FieldValue<String?>.value(nil) != .notAuthorized)
}

@Test func unifiedAndUnderlyingContactsCannotAlias() throws {
    let container = try ContactContainerReference(
        account: account(), localID: DomainID("container"))
    let item = try ContactID("same-id")
    let record = ContactRecordReference(container: container, item: item)
    let unified = ContactReference.unified(
        provider: container.account.provider, store: container.account.store, item: item)
    #expect(unified != .record(record))
    let contact = Contact(id: unified, linkedRecords: .value([record]))
    #expect(contact.id == unified)
    #expect(contact.linkedRecords == .value([record]))
}

@Test func patchesDistinguishClearKeepAndExactChangedFields() throws {
    #expect(throws: DomainValidationError.emptyChange) { try EventChanges() }
    #expect(throws: DomainValidationError.emptyChange) { try ReminderChanges() }
    #expect(throws: DomainValidationError.emptyChange) { try ContactChanges() }
    let changes = try ContactChanges(emailAddresses: .set([]), notes: .set(nil))
    #expect(changes.changedFields == [.emailAddresses, .notes])
    #expect(changes.name == .unchanged)
    let event = try EventChanges(notes: .set(nil))
    #expect(event.notes != .unchanged)
    #expect(event.title == .unchanged)
    let reminder = try ReminderChanges(notes: .set("Synthetic note"))
    #expect(reminder.title == .unchanged)
}

@Test func proposalEqualityBindsConnectionTargetChangesAndPrecondition() throws {
    let id = try OperationID("synthetic-operation")
    let connection = try ConnectionID("synthetic-requester")
    let target = try reference()
    let patch = try EventChanges(title: .set("Synthetic title"))
    let revision = try MutationPrecondition.revision(ObservedRevision("opaque-version"))
    let change = CalendarMutation.update(target, changes: patch, precondition: revision)
    let proposal = ProposedChange(id: id, connection: connection, change: change)
    #expect(proposal == ProposedChange(id: id, connection: connection, change: change))
    #expect(
        proposal != ProposedChange(id: id, connection: try ConnectionID("other"), change: change))
    #expect(
        proposal
            != ProposedChange(
                id: id, connection: connection,
                change: .update(target, changes: patch, precondition: .unknown)))
    #expect(
        proposal
            != ProposedChange(
                id: id, connection: connection,
                change: .update(
                    target, changes: try EventChanges(title: .set("Other")), precondition: revision)
            ))
    #expect(
        proposal
            != ProposedChange(
                id: id, connection: connection,
                change: .update(
                    try reference(anchor: .timed(instant(10))), changes: patch,
                    precondition: revision)))
    #expect(
        proposal
            != ProposedChange(
                id: id, connection: connection, change: .delete(target, precondition: revision)))
}

@Test func mutationVocabularyDoesNotImplyBroaderPermissions() throws {
    let list = try ReminderListReference(account: account(), localID: DomainID("list"))
    let reminder = try ReminderReference(list: list, item: ReminderID("item"))
    #expect(
        ReminderMutation.setDue(reminder, due: nil, precondition: .unknown).operation
            == .changeDueDate)
    #expect(ReminderMutation.complete(reminder, precondition: .unknown).operation == .complete)
    #expect(ReminderMutation.delete(reminder, precondition: .unknown).operation == .delete)
    #expect(CalendarMutation.delete(try reference(), precondition: .unknown).operation == .delete)
    let record = try ContactRecordReference(
        container: ContactContainerReference(account: account(), localID: DomainID("container")),
        item: ContactID("item"))
    #expect(ContactMutation.delete(record, precondition: .unknown).operation == .delete)
}

@Test func unknownWritesAreNotFailuresOrSuccesses() {
    let outcomes: [MutationResult<Int>] = [.succeeded(1), .conflict, .failed(.denied), .unknown]
    let categories = outcomes.map { outcome in
        switch outcome {
        case .succeeded: "success"
        case .conflict: "conflict"
        case .failed: "failed"
        case .unknown: "unknown"
        }
    }
    #expect(Set(categories).count == 4)
}

@Test func destinationRecoveryDoesNotInventOwnershipOrIdentity() throws {
    let missing = CalendarDestination(reference: .missing, ownership: .unknown)
    let ambiguous = CalendarDestination(reference: .ambiguous, ownership: .unknown)
    let resolved = try CalendarDestination(reference: .resolved(calendar()), ownership: .unknown)
    #expect(missing != ambiguous)
    #expect(missing != resolved)
    #expect(resolved.ownership == .unknown)
    #expect(
        resolved
            != CalendarDestination(reference: resolved.reference, ownership: .verifiedAppCreated))
}

private struct SyntheticReader: CalendarReading {
    let snapshot: CalendarSnapshot

    func discoverCalendars() async -> ProviderReadResult<ResourceDiscovery<CalendarResource>> {
        .observed(ResourceDiscovery(resources: [], observation: snapshot.observation))
    }

    func readOccurrences(_ request: CalendarReadRequest, fields: Set<CalendarDetailField>) async
        -> ProviderReadResult<
            CalendarSnapshot
        >
    {
        guard request == snapshot.coverage else { return .failed(.denied) }
        return .observed(snapshot)
    }
}

@Test func sourceReaderNeedsNoWriterImplementation() async throws {
    let expected = try CalendarSnapshot(
        coverage: request(), occurrences: [occurrence()], observation: observation())
    let reader: any CalendarReading = SyntheticReader(snapshot: expected)
    let result = await reader.readOccurrences(expected.coverage)
    guard case .observed(let actual) = result else {
        Issue.record("Synthetic read failed")
        return
    }
    #expect(actual == expected)
}

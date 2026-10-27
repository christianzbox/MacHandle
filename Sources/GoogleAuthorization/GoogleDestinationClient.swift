import Foundation

/// Trusted infrastructure only, not composed into the app. No public live activation factory.
/// Capabilities derive from successful creation in this session, never remote names/markers alone.
actor GoogleDestinationClient {
    private struct CalendarRecord {
        let id: String
        let marker: String
        let lease: GoogleCalendarLease
    }
    private struct InsertRecord {
        let destination: GoogleDestination
        let id: String
        let operation: String
        let content: GoogleEventContent
        var attempted = false
    }
    private struct Observation {
        let insert: GoogleEventInsert
        let etag: String
        let content: GoogleEventContent
    }
    private struct CalendarWire: Codable {
        let id: String?
        let summary: String?
        let description: String?
        let etag: String?
    }
    private struct Page: Decodable {
        let items: [GoogleEventWire]?
        let nextPageToken: String?
    }
    private struct APIError: Decodable {
        struct Detail: Decodable { let reason: String }
        struct Body: Decodable { let errors: [Detail]? }
        let error: Body
    }
    private let transport: any GoogleCalendarSending
    private let sleep: @Sendable (Double) async throws -> Void
    private let jitter: @Sendable () -> Double
    private var destination: (GoogleDestination, CalendarRecord)?
    private var creationAttempted = false
    private var inserts: [GoogleEventInsert: InsertRecord] = [:]
    private var observations: [GoogleObservedEvent: Observation] = [:]
    private var busy = false
    private var durableAttempts = Set<UUID>()

    init(
        transport: any GoogleCalendarSending,
        sleep: @escaping @Sendable (Double) async throws -> Void = {
            try await Task.sleep(for: .seconds($0))
        },
        jitter: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
    ) {
        self.transport = transport
        self.sleep = sleep
        self.jitter = jitter
    }

    /// A failed/disconnected create is not permission to create again: calendar inserts lack a stable ID.
    func createDestination(ownershipMarker: UUID = UUID()) async throws -> GoogleDestination {
        try begin()
        defer { busy = false }
        guard !creationAttempted else { throw GoogleDestinationFailure.recoveryRequired }
        let lease = try await transport.calendarLease()
        let marker = ownershipMarker.uuidString
        let body = try JSONEncoder().encode(
            CalendarWire(
                id: nil, summary: "MacHandle — Availability", description: marker, etag: nil))
        let request = try GoogleCalendarRequest.make(method: "POST", body: body)
        creationAttempted = true
        let data = try await perform(request, lease: lease)
        let value: CalendarWire = try decode(data)
        guard let id = value.id, GoogleCalendarRequest.validCalendarID(id),
            value.description == marker,
            let etag = value.etag, GoogleCalendarRequest.validETag(etag)
        else { throw GoogleDestinationFailure.outcomeUnknown }
        let handle = GoogleDestination(nonce: UUID())
        destination = (handle, CalendarRecord(id: id, marker: marker, lease: lease))
        return handle
    }

    func verifyDestination(_ handle: GoogleDestination) async throws {
        try begin()
        defer { busy = false }
        _ = try await verify(handle)
    }

    /// Caller retains the same handle after an uncertain insert. Persistence comes in package 10.
    func prepareInsert(in handle: GoogleDestination, content: GoogleEventContent) throws
        -> GoogleEventInsert
    {
        guard !busy else { throw GoogleDestinationFailure.unavailable }
        _ = try record(handle)
        try content.validate()
        guard inserts.count < 10_000 else { throw GoogleDestinationFailure.limitExceeded }
        let key = GoogleEventInsert(nonce: UUID())
        inserts[key] = InsertRecord(
            destination: handle,
            id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            operation: UUID().uuidString.lowercased(), content: content)
        return key
    }

    func insert(_ key: GoogleEventInsert) async throws -> GoogleObservedEvent {
        try begin()
        defer { busy = false }
        guard var planned = inserts[key] else { throw GoogleDestinationFailure.ownership }
        guard !planned.attempted else { throw GoogleDestinationFailure.recoveryRequired }
        let calendar = try await verify(planned.destination)
        let wire = GoogleEventWire(
            id: planned.id, owner: calendar.marker, operation: planned.operation,
            content: planned.content)
        let request = try GoogleCalendarRequest.make(
            method: "POST", calendar: calendar.id, events: true,
            query: notificationQuery, body: JSONEncoder().encode(wire))
        planned.attempted = true
        inserts[key] = planned
        do {
            let data = try await perform(request, lease: calendar.lease)
            return try observe(
                decode(data), key: key, calendar: calendar, expected: planned.content)
        } catch let failure as GoogleDestinationFailure {
            // A duplicate ID needs the same identity/content verification as a lost response.
            if failure == .conflict { throw GoogleDestinationFailure.outcomeUnknown }
            throw failure
        } catch { throw GoogleDestinationFailure.outcomeUnknown }
    }

    /// Explicit GET verification, never an automatic second POST (including after 404).
    func verifyInsert(_ key: GoogleEventInsert) async throws -> GoogleObservedEvent {
        try await read(key, expectedInsert: true)
    }
    func readEvent(_ key: GoogleEventInsert) async throws -> GoogleObservedEvent {
        try await read(key, expectedInsert: false)
    }
    private func read(_ key: GoogleEventInsert, expectedInsert: Bool) async throws
        -> GoogleObservedEvent
    {
        try begin()
        defer { busy = false }
        guard let planned = inserts[key], planned.attempted else {
            throw GoogleDestinationFailure.ownership
        }
        let calendar = try await verify(planned.destination)
        let data = try await perform(
            GoogleCalendarRequest.make(
                method: "GET", calendar: calendar.id,
                event: planned.id, events: true), lease: calendar.lease)
        return try observe(
            decode(data), key: key, calendar: calendar,
            expected: expectedInsert ? planned.content : nil)
    }

    /// Complete-or-error, bounded inventory. Even success is not an atomic snapshot or deletion authority.
    func listEvents(in handle: GoogleDestination) async throws -> [GoogleObservedEvent] {
        try begin()
        defer { busy = false }
        let calendar = try await verify(handle)
        var token: String?
        var seenTokens = Set<String>()
        var seenIDs = Set<String>()
        var fetched: [(GoogleEventWire, GoogleEventInsert)] = []
        let knownEvents = Dictionary(
            uniqueKeysWithValues: inserts.compactMap { key, value in
                value.destination == handle ? (value.id, key) : nil
            })
        for _ in 0..<100 {
            var query = [
                URLQueryItem(name: "maxResults", value: "100"),
                URLQueryItem(name: "showDeleted", value: "false"),
                URLQueryItem(name: "singleEvents", value: "false"),
            ]
            if let token { query.append(URLQueryItem(name: "pageToken", value: token)) }
            let data = try await perform(
                GoogleCalendarRequest.make(
                    method: "GET", calendar: calendar.id,
                    events: true, query: query), lease: calendar.lease)
            let page: Page = try decode(data)
            for wire in page.items ?? [] {
                guard seenIDs.insert(wire.id).inserted, fetched.count < 10_000,
                    let key = knownEvents[wire.id]
                else { throw GoogleDestinationFailure.ownership }
                try validate(wire, key: key, calendar: calendar, expected: nil)
                fetched.append((wire, key))
            }
            guard let next = page.nextPageToken else {
                guard observations.count + fetched.count <= 10_000 else {
                    throw GoogleDestinationFailure.limitExceeded
                }
                return try fetched.map {
                    try observe($0.0, key: $0.1, calendar: calendar, expected: nil)
                }
            }
            guard !next.isEmpty, next.utf8.count <= 2048, seenTokens.insert(next).inserted else {
                throw GoogleDestinationFailure.invalidResponse
            }
            token = next
        }
        throw GoogleDestinationFailure.limitExceeded
    }

    func update(_ observed: GoogleObservedEvent, content: GoogleEventContent) async throws
        -> GoogleObservedEvent
    {
        try begin()
        defer { busy = false }
        try content.validate()
        let (observation, planned) = try observation(observed)
        let calendar = try await verify(planned.destination)
        let wire = GoogleEventWire(
            id: planned.id, owner: calendar.marker, operation: planned.operation, content: content)
        let request = try GoogleCalendarRequest.make(
            method: "PUT", calendar: calendar.id, event: planned.id,
            events: true, query: notificationQuery, body: JSONEncoder().encode(wire),
            etag: observation.etag)
        observations[observed] = nil  // consume even on conflict/unknown; refetch before replanning
        let data = try await perform(request, lease: calendar.lease)
        return try observe(
            decode(data), key: observation.insert, calendar: calendar, expected: content)
    }

    func delete(_ observed: GoogleObservedEvent) async throws {
        try begin()
        defer { busy = false }
        let (observation, planned) = try observation(observed)
        let calendar = try await verify(planned.destination)
        let request = try GoogleCalendarRequest.make(
            method: "DELETE", calendar: calendar.id,
            event: planned.id, events: true, query: notificationQuery, etag: observation.etag)
        observations[observed] = nil
        _ = try await perform(request, lease: calendar.lease)
    }

    func content(of observed: GoogleObservedEvent) throws -> GoogleEventContent {
        guard let value = observations[observed] else { throw GoogleDestinationFailure.ownership }
        return value.content
    }

    private var notificationQuery: [URLQueryItem] {
        [URLQueryItem(name: "sendUpdates", value: "none")]
    }
    private func begin() throws {
        try Task.checkCancellation()
        guard !busy else { throw GoogleDestinationFailure.unavailable }
        busy = true
    }
    private func record(_ handle: GoogleDestination) throws -> CalendarRecord {
        guard let (known, record) = destination, handle == known else {
            throw GoogleDestinationFailure.ownership
        }
        return record
    }
    private func verify(
        _ handle: GoogleDestination, beforeSend: (@Sendable () async throws -> Void)? = nil
    ) async throws -> CalendarRecord {
        let calendar = try record(handle)
        guard try await transport.calendarLease() == calendar.lease else {
            throw GoogleDestinationFailure.authorization
        }
        let data = try await perform(
            GoogleCalendarRequest.make(method: "GET", calendar: calendar.id), lease: calendar.lease,
            beforeSend: beforeSend)
        let wire: CalendarWire = try decode(data)
        guard wire.id == calendar.id, wire.description == calendar.marker else {
            throw GoogleDestinationFailure.ownership
        }
        return calendar
    }
    private func observation(_ key: GoogleObservedEvent) throws -> (Observation, InsertRecord) {
        guard let observed = observations[key], let planned = inserts[observed.insert] else {
            throw GoogleDestinationFailure.ownership
        }
        return (observed, planned)
    }
    private func validate(
        _ wire: GoogleEventWire, key: GoogleEventInsert, calendar: CalendarRecord,
        expected: GoogleEventContent?
    ) throws {
        guard let planned = inserts[key], wire.id == planned.id,
            wire.extendedProperties?.private["macHandleOwner"] == calendar.marker,
            wire.extendedProperties?.private["macHandleOperation"] == planned.operation,
            let etag = wire.etag, GoogleCalendarRequest.validETag(etag)
        else { throw GoogleDestinationFailure.ownership }
        let actual = try wire.content()
        if let expected {
            guard actual == expected, wire.visibility == "private",
                wire.reminders?.useDefault == false
            else {
                throw GoogleDestinationFailure.conflict
            }
        }
    }
    private func observe(
        _ wire: GoogleEventWire, key: GoogleEventInsert, calendar: CalendarRecord,
        expected: GoogleEventContent?
    ) throws -> GoogleObservedEvent {
        try validate(wire, key: key, calendar: calendar, expected: expected)
        guard observations.count < 10_000 else { throw GoogleDestinationFailure.limitExceeded }
        let handle = GoogleObservedEvent(nonce: UUID())
        observations[handle] = Observation(
            insert: key, etag: wire.etag!, content: try wire.content())
        return handle
    }
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        guard data.count <= 65_536, let value = try? JSONDecoder().decode(T.self, from: data) else {
            throw GoogleDestinationFailure.invalidResponse
        }
        return value
    }

    private func perform(
        _ request: URLRequest, lease: GoogleCalendarLease,
        beforeSend: (@Sendable () async throws -> Void)? = nil
    ) async throws -> Data {
        let read = request.httpMethod == "GET"
        for attempt in 0..<3 {
            try Task.checkCancellation()
            guard try await transport.calendarLease() == lease else {
                throw GoogleDestinationFailure.authorization
            }
            try await beforeSend?()
            try Task.checkCancellation()
            let response: OAuthHTTPResponse
            do { response = try await transport.sendCalendar(request, lease: lease) } catch {
                if Task.isCancelled { throw GoogleDestinationFailure.cancelled }
                if let failure = error as? GoogleDestinationFailure,
                    failure == .authorization || failure == .cancelled
                {
                    throw failure
                }
                // A dispatched mutation might have committed. Never blindly replay it.
                guard read else { throw GoogleDestinationFailure.outcomeUnknown }
                guard attempt < 2 else { throw GoogleDestinationFailure.unavailable }
                try await sleep(pow(2, Double(attempt)) + boundedJitter())
                continue
            }
            try Task.checkCancellation()
            guard try await transport.calendarLease() == lease else {
                throw GoogleDestinationFailure.authorization
            }
            guard response.data.count <= 65_536 else {
                throw read ? GoogleDestinationFailure.invalidResponse : .outcomeUnknown
            }
            let success =
                request.httpMethod == "DELETE"
                ? response.status == 204 : response.status == 200 || response.status == 201
            if success { return response.data }
            if response.status == 401 { throw GoogleDestinationFailure.authorization }
            if response.status == 404 || response.status == 410 {
                throw GoogleDestinationFailure.notFound
            }
            if response.status == 409 || response.status == 412 {
                throw GoogleDestinationFailure.conflict
            }
            let reasons =
                (try? JSONDecoder().decode(APIError.self, from: response.data))?.error.errors?.map(
                    \.reason) ?? []
            let rate =
                response.status == 429
                || (response.status == 403 && !reasons.isEmpty
                    && reasons.allSatisfy {
                        ["rateLimitExceeded", "userRateLimitExceeded"].contains($0)
                    })
            let transient = (500...599).contains(response.status)
            if rate || (read && transient) {
                // Only known rejection responses retry writes; 5xx writes remain uncertain.
                guard attempt < 2 else {
                    throw rate ? GoogleDestinationFailure.rateLimited : .unavailable
                }
                var delay = pow(2, Double(attempt)) + boundedJitter()
                if let header = response.retryAfter {
                    guard let seconds = Double(header), seconds.isFinite, (0...30).contains(seconds)
                    else {
                        // Never retry early for a long or date-form hint.
                        throw GoogleDestinationFailure.rateLimited
                    }
                    delay = max(delay, seconds)
                }
                try await sleep(delay)
                continue
            }
            if transient { throw GoogleDestinationFailure.outcomeUnknown }
            throw response.status == 403 ? GoogleDestinationFailure.authorization : .invalidResponse
        }
        throw GoogleDestinationFailure.unavailable
    }
    private func boundedJitter() -> Double {
        let value = jitter()
        return value.isFinite ? min(max(value, 0), 1) : 0
    }
}

extension GoogleDestinationClient {
    /// Only an already session-owned calendar can create this package-only bridge.
    func durableDestination(_ handle: GoogleDestination) throws -> GoogleDurableDestination {
        let calendar = try record(handle)
        return GoogleDurableDestination(
            calendarID: calendar.id, marker: calendar.marker,
            dispatch: { command, check in
                try await self.dispatchDurable(command, in: handle, check: check)
            },
            verify: { command, check in
                try await self.verifyDurable(command, in: handle, check: check)
            })
    }
    private func dispatchDurable(
        _ command: GoogleDurableCommand, in handle: GoogleDestination,
        check: @escaping @Sendable () async throws -> Void
    ) async throws {
        try begin()
        defer { busy = false }
        try command.validate()
        guard durableAttempts.count < 10_000, durableAttempts.insert(command.operationID).inserted
        else {
            throw GoogleDestinationFailure.recoveryRequired
        }
        let calendar = try await verify(handle, beforeSend: check)
        if command.kind != .insert {
            let wire = try await durableRead(command, calendar: calendar, check: check)
            try durableValidate(wire, command: command, calendar: calendar)
            guard wire.etag == command.expectedETag, try wire.content() == command.previousContent
            else {
                throw GoogleDestinationFailure.conflict
            }
        }
        var body: Data?
        if let content = command.content {
            var wire = GoogleEventWire(
                id: command.eventID, owner: calendar.marker,
                operation: command.creationID.uuidString, content: content)
            wire.extendedProperties?.private["macHandleMutation"] = command.operationID.uuidString
            body = try JSONEncoder().encode(wire)
        }
        let method = command.kind == .insert ? "POST" : command.kind == .update ? "PUT" : "DELETE"
        _ = try await perform(
            GoogleCalendarRequest.make(
                method: method, calendar: calendar.id,
                event: command.kind == .insert ? nil : command.eventID, events: true,
                query: notificationQuery, body: body, etag: command.expectedETag),
            lease: calendar.lease, beforeSend: check)
    }
    private func verifyDurable(
        _ command: GoogleDurableCommand, in handle: GoogleDestination,
        check: @escaping @Sendable () async throws -> Void
    ) async throws -> String? {
        try begin()
        defer { busy = false }
        try command.validate()
        let calendar = try await verify(handle, beforeSend: check)
        let wire: GoogleEventWire
        do {
            wire = try await durableRead(command, calendar: calendar, check: check)
        } catch GoogleDestinationFailure.notFound {
            guard command.kind == .delete else { throw GoogleDestinationFailure.recoveryRequired }
            return nil
        }
        guard command.kind != .delete else { throw GoogleDestinationFailure.recoveryRequired }
        try durableValidate(wire, command: command, calendar: calendar)
        guard
            wire.extendedProperties?.private["macHandleMutation"] == command.operationID.uuidString,
            try wire.content() == command.content
        else { throw GoogleDestinationFailure.conflict }
        return wire.etag
    }
    private func durableRead(
        _ command: GoogleDurableCommand, calendar: CalendarRecord,
        check: @escaping @Sendable () async throws -> Void
    ) async throws -> GoogleEventWire {
        try decode(
            await perform(
                GoogleCalendarRequest.make(
                    method: "GET", calendar: calendar.id,
                    event: command.eventID, events: true), lease: calendar.lease, beforeSend: check)
        )
    }
    private func durableValidate(
        _ wire: GoogleEventWire, command: GoogleDurableCommand,
        calendar: CalendarRecord
    ) throws {
        guard wire.id == command.eventID,
            wire.extendedProperties?.private["macHandleOwner"] == calendar.marker,
            wire.extendedProperties?.private["macHandleOperation"] == command.creationID.uuidString,
            let etag = wire.etag, GoogleCalendarRequest.validETag(etag),
            wire.visibility == "private", wire.reminders?.useDefault == false
        else {
            throw GoogleDestinationFailure.ownership
        }
        _ = try wire.content()
    }
}

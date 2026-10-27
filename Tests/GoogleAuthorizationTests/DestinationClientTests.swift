import Foundation
import Testing

@testable import GoogleAuthorization

private actor CalendarFixture: GoogleCalendarSending {
    var lease = GoogleCalendarLease(authority: UUID(), generation: 1)
    var calendar: [String: String] = [:]
    var events: [String: GoogleEventWire] = [:]
    private(set) var requests: [URLRequest] = []
    var overrides: [OAuthHTTPResponse] = []
    var loseInsertResponse = false
    var wrongCalendar = false
    var wrongEvent = false
    var hasGuest = false
    var revision = 1
    func calendarLease() -> GoogleCalendarLease { lease }
    func disconnect() {
        lease = GoogleCalendarLease(authority: lease.authority, generation: lease.generation + 1)
    }
    func queue(_ values: [OAuthHTTPResponse]) { overrides = values }
    func configure(
        lost: Bool = false, wrongCalendar: Bool = false, wrongEvent: Bool = false,
        guest: Bool = false
    ) {
        loseInsertResponse = lost
        self.wrongCalendar = wrongCalendar
        self.wrongEvent = wrongEvent
        hasGuest = guest
    }
    func sendCalendar(_ request: URLRequest, lease: GoogleCalendarLease) throws -> OAuthHTTPResponse
    {
        guard lease == self.lease else { throw GoogleDestinationFailure.authorization }
        requests.append(request)
        #expect(request.url?.host == "www.googleapis.com")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        if !overrides.isEmpty { return overrides.removeFirst() }
        let method = request.httpMethod!
        let path = request.url!.path
        if !path.contains("/events") {
            if method == "POST" {
                calendar = try JSONDecoder().decode([String: String].self, from: request.httpBody!)
                calendar["id"] = "synthetic-destination@group.calendar.google.com"
                calendar["etag"] = "\"calendar-1\""
            }
            var result = calendar
            if wrongCalendar { result["description"] = "untrusted replacement" }
            return OAuthHTTPResponse(status: 200, data: try JSONEncoder().encode(result))
        }
        if method == "POST" || method == "PUT" {
            var wire = try JSONDecoder().decode(GoogleEventWire.self, from: request.httpBody!)
            if method == "PUT",
                request.value(forHTTPHeaderField: "If-Match") != events[wire.id]?.etag
            {
                return OAuthHTTPResponse(status: 412, data: Data())
            }
            revision += 1
            wire.etag = "\"revision-\(revision)\""
            wire.status = "confirmed"
            events[wire.id] = wire
            if loseInsertResponse { throw GoogleDestinationFailure.unavailable }
            return OAuthHTTPResponse(status: 200, data: try JSONEncoder().encode(wire))
        }
        if method == "DELETE" {
            let id = request.url!.lastPathComponent
            guard events[id]?.etag == request.value(forHTTPHeaderField: "If-Match") else {
                return OAuthHTTPResponse(status: 412, data: Data())
            }
            events[id] = nil
            return OAuthHTTPResponse(status: 204, data: Data())
        }
        if path.hasSuffix("/events") {
            let items = try JSONEncoder().encode(Array(events.values))
            return OAuthHTTPResponse(
                status: 200, data: Data("{\"items\":".utf8) + items + Data("}".utf8))
        }
        guard var wire = events[request.url!.lastPathComponent] else {
            return OAuthHTTPResponse(status: 404, data: Data())
        }
        if wrongEvent { wire.extendedProperties?.private["macHandleOwner"] = "untrusted" }
        if hasGuest { wire.attendees = [.init(email: "synthetic@example.invalid")] }
        return OAuthHTTPResponse(status: 200, data: try JSONEncoder().encode(wire))
    }
    func editRemote() {
        for key in events.keys { events[key]?.etag = "\"externally-changed\"" }
    }
}
private actor Delays {
    var values: [Double] = []
    func add(_ value: Double) { values.append(value) }
}
private func content(detailed: Bool = false) throws -> GoogleEventContent {
    try GoogleEventContent(
        start: GoogleEventTime(day: "2026-10-27"), end: GoogleEventTime(day: "2026-10-28"),
        summary: detailed ? "Synthetic appointment" : "Busy",
        description: detailed ? "Synthetic detail" : "",
        location: detailed ? "Synthetic room" : "")
}
private func destinationSetup() async throws -> (
    CalendarFixture, GoogleDestinationClient, GoogleDestination
) {
    let fixture = CalendarFixture()
    let client = GoogleDestinationClient(transport: fixture, sleep: { _ in }, jitter: { 0 })
    let destination = try await client.createDestination()
    return (fixture, client, destination)
}

@Test func destinationCRUDUsesOwnedIDsConditionalWritesAndWhitelistedPayloads() async throws {
    let (fixture, client, destination) = try await destinationSetup()
    let planned = try await client.prepareInsert(in: destination, content: content(detailed: true))
    let inserted = try await client.insert(planned)
    #expect(try await client.content(of: inserted) == content(detailed: true))
    let updated = try await client.update(inserted, content: content())
    let listed = try await client.listEvents(in: destination)
    #expect(listed.count == 1)
    #expect(try await client.content(of: updated) == content())
    try await client.delete(updated)
    #expect(try await client.listEvents(in: destination).isEmpty)
    let requests = await fixture.requests
    let writes = requests.filter { ["PUT", "DELETE"].contains($0.httpMethod) }
    #expect(
        writes.count == 2 && writes.allSatisfy { $0.value(forHTTPHeaderField: "If-Match") != nil })
    let put = try #require(requests.first { $0.httpMethod == "PUT" })
    let json = try #require(JSONSerialization.jsonObject(with: put.httpBody!) as? [String: Any])
    #expect(json["description"] as? String == "" && json["location"] as? String == "")
    #expect(json["attendees"] == nil && json["conferenceData"] == nil && json["recurrence"] == nil)
    #expect(put.url?.query == "sendUpdates=none")
    #expect(
        !requests.contains {
            $0.url!.path.contains("primary") || $0.url!.path.contains("calendarList")
                || $0.url!.path.contains("acl")
        })
}

@Test func destinationHandlesAndMarkersCannotAuthorizeAnotherCalendar() async throws {
    let (fixture, client, destination) = try await destinationSetup()
    let before = await fixture.requests.count
    await #expect(throws: GoogleDestinationFailure.ownership) {
        try await client.verifyDestination(GoogleDestination(nonce: UUID()))
    }
    #expect(await fixture.requests.count == before)
    await fixture.configure(wrongCalendar: true)
    let key = try await client.prepareInsert(in: destination, content: content())
    await #expect(throws: GoogleDestinationFailure.ownership) { try await client.insert(key) }
    #expect(await fixture.requests.filter { $0.httpMethod == "POST" }.count == 1)
}

@Test func lostInsertResponseRequiresSameIdentityVerificationAndNeverReposts() async throws {
    let (fixture, client, destination) = try await destinationSetup()
    let key = try await client.prepareInsert(in: destination, content: content())
    await fixture.configure(lost: true)
    await #expect(throws: GoogleDestinationFailure.outcomeUnknown) { try await client.insert(key) }
    await #expect(throws: GoogleDestinationFailure.recoveryRequired) {
        try await client.insert(key)
    }
    _ = try await client.verifyInsert(key)
    #expect(
        await fixture.requests.filter {
            $0.httpMethod == "POST" && $0.url!.path.hasSuffix("/events")
        }.count == 1)
    await fixture.configure(wrongEvent: true)
    await #expect(throws: GoogleDestinationFailure.ownership) { try await client.verifyInsert(key) }
}

@Test func changedVersionsAndGuestEditsStopWrites() async throws {
    let (fixture, client, destination) = try await destinationSetup()
    let key = try await client.prepareInsert(in: destination, content: content())
    let first = try await client.insert(key)
    await fixture.editRemote()
    await #expect(throws: GoogleDestinationFailure.conflict) {
        try await client.update(first, content: content(detailed: true))
    }
    await #expect(throws: GoogleDestinationFailure.ownership) { try await client.delete(first) }
    let current = try await client.readEvent(key)
    await fixture.configure(guest: true)
    await #expect(throws: GoogleDestinationFailure.invalidResponse) {
        try await client.readEvent(key)
    }
    await fixture.configure()
    try await client.delete(current)
}

@Test func interruptedCalendarCreationDoesNotRetryOrDiscoverByTitle() async throws {
    let fixture = CalendarFixture()
    await fixture.queue([OAuthHTTPResponse(status: 503, data: Data())])
    let client = GoogleDestinationClient(transport: fixture)
    await #expect(throws: GoogleDestinationFailure.outcomeUnknown) {
        try await client.createDestination()
    }
    await #expect(throws: GoogleDestinationFailure.recoveryRequired) {
        try await client.createDestination()
    }
    #expect(await fixture.requests.count == 1)
}

@Test func destinationPaginationFollowsEmptyPagesAndRejectsCyclesAndPartialFailures() async throws {
    for failure in [false, true] {
        let (fixture, client, destination) = try await destinationSetup()
        let calendar = try await JSONEncoder().encode(fixture.calendar)
        await fixture.queue([
            OAuthHTTPResponse(status: 200, data: calendar),
            OAuthHTTPResponse(
                status: 200, data: Data("{\"items\":[],\"nextPageToken\":\"synthetic-page\"}".utf8)),
            OAuthHTTPResponse(
                status: failure ? 403 : 200,
                data: Data("{\"items\":[],\"nextPageToken\":\"synthetic-page\"}".utf8)),
        ])
        await #expect(throws: failure ? GoogleDestinationFailure.authorization : .invalidResponse) {
            try await client.listEvents(in: destination)
        }
        #expect(
            await fixture.requests.last?.url?.query?.contains("pageToken=synthetic-page") == true)
    }
    let (fixture, client, destination) = try await destinationSetup()
    let calendar = try await JSONEncoder().encode(fixture.calendar)
    await fixture.queue([
        .init(status: 200, data: calendar),
        .init(status: 200, data: Data("{\"nextPageToken\":\"synthetic-last\"}".utf8)),
        .init(status: 200, data: Data("{\"items\":[]}".utf8)),
    ])
    #expect(try await client.listEvents(in: destination).isEmpty)
}

@Test func boundedBackoffHonorsRetryAfterAndNeverRetriesMutation5xx() async throws {
    let fixture = CalendarFixture()
    let delays = Delays()
    let client = GoogleDestinationClient(
        transport: fixture, sleep: { await delays.add($0) }, jitter: { 0.5 })
    let destination = try await client.createDestination()
    await fixture.queue([
        .init(status: 429, data: Data(), retryAfter: "4"), .init(status: 503, data: Data()),
    ])
    try await client.verifyDestination(destination)
    #expect(await delays.values == [4, 2.5])
    await fixture.queue(Array(repeating: .init(status: 429, data: Data()), count: 3))
    await #expect(throws: GoogleDestinationFailure.rateLimited) {
        try await client.verifyDestination(destination)
    }
    let key = try await client.prepareInsert(in: destination, content: content())
    let calendar = try await JSONEncoder().encode(fixture.calendar)
    await fixture.queue([.init(status: 200, data: calendar), .init(status: 503, data: Data())])
    await #expect(throws: GoogleDestinationFailure.outcomeUnknown) { try await client.insert(key) }
    #expect(
        await fixture.requests.filter {
            $0.httpMethod == "POST" && $0.url!.path.hasSuffix("/events")
        }.count == 1)
}

@Test func longRetryAfterAndNonQuota403DoNotRetry() async throws {
    for response in [
        OAuthHTTPResponse(status: 429, data: Data(), retryAfter: "3600"),
        OAuthHTTPResponse(
            status: 403, data: Data("{\"error\":{\"errors\":[{\"reason\":\"forbidden\"}]}}".utf8)),
    ] {
        let (fixture, client, destination) = try await destinationSetup()
        let before = await fixture.requests.count
        await fixture.queue([response])
        await #expect(
            throws: response.status == 429 ? GoogleDestinationFailure.rateLimited : .authorization
        ) {
            try await client.verifyDestination(destination)
        }
        #expect(await fixture.requests.count == before + 1)
    }
}

@Test func reconnectAndCancelledBackoffInvalidateOperations() async throws {
    let (fixture, client, destination) = try await destinationSetup()
    await fixture.disconnect()
    await #expect(throws: GoogleDestinationFailure.authorization) {
        try await client.verifyDestination(destination)
    }
    #expect(await fixture.requests.count == 1)
    let fixture2 = CalendarFixture()
    let client2 = GoogleDestinationClient(
        transport: fixture2, sleep: { _ in throw CancellationError() })
    let handle = try await client2.createDestination()
    await fixture2.queue([.init(status: 429, data: Data())])
    await #expect(throws: CancellationError.self) { try await client2.verifyDestination(handle) }
    #expect(await fixture2.requests.count == 2)
}

@Test func requestsEncodeOpaqueCalendarPathsAndRejectAliasesVersionsAndInvalidDates() throws {
    #expect(throws: GoogleDestinationFailure.invalidInput) {
        try GoogleCalendarRequest.make(method: "GET", calendar: "primary")
    }
    #expect(throws: GoogleDestinationFailure.invalidInput) {
        try GoogleCalendarRequest.make(
            method: "DELETE", calendar: "synthetic", event: "abcde", events: true, etag: "*")
    }
    let request = try GoogleCalendarRequest.make(
        method: "GET", calendar: "synthetic/a?b#c@group.calendar.google.com")
    #expect(
        request.url!.absoluteString.contains("synthetic%2Fa%3Fb%23c%40group.calendar.google.com"))
    #expect(request.url!.query == nil && request.url!.fragment == nil)
    #expect(throws: GoogleDestinationFailure.invalidInput) {
        try GoogleEventTime(day: "2026-02-30")
    }
    #expect(throws: GoogleDestinationFailure.invalidInput) {
        try GoogleEventContent(
            start: GoogleEventTime(day: "2026-10-28"), end: GoogleEventTime(day: "2026-10-27"))
    }
}

@Test func paginationBoundsAndOversizedResponsesFailWithoutReturningInventory() async throws {
    let (fixture, client, destination) = try await destinationSetup()
    let calendar = try await JSONEncoder().encode(fixture.calendar)
    var pages: [OAuthHTTPResponse] = [.init(status: 200, data: calendar)]
    for index in 0..<100 {
        pages.append(
            .init(
                status: 200,
                data: Data("{\"items\":[],\"nextPageToken\":\"synthetic-\(index)\"}".utf8)))
    }
    await fixture.queue(pages)
    await #expect(throws: GoogleDestinationFailure.limitExceeded) {
        try await client.listEvents(in: destination)
    }
    #expect(await fixture.requests.count == 102)
    await fixture.queue([
        .init(status: 200, data: calendar),
        .init(status: 200, data: Data(repeating: 32, count: 65_537)),
    ])
    await #expect(throws: GoogleDestinationFailure.invalidResponse) {
        try await client.listEvents(in: destination)
    }
}

@Test func insertCollisionRequiresReadVerificationAndDoesNotTreat404AsRetryPermission() async throws
{
    let (fixture, client, destination) = try await destinationSetup()
    let key = try await client.prepareInsert(in: destination, content: content())
    let calendar = try await JSONEncoder().encode(fixture.calendar)
    await fixture.queue([.init(status: 200, data: calendar), .init(status: 409, data: Data())])
    await #expect(throws: GoogleDestinationFailure.outcomeUnknown) { try await client.insert(key) }
    await #expect(throws: GoogleDestinationFailure.notFound) { try await client.verifyInsert(key) }
    await #expect(throws: GoogleDestinationFailure.recoveryRequired) {
        try await client.insert(key)
    }
    #expect(
        await fixture.requests.filter {
            $0.httpMethod == "POST" && $0.url!.path.hasSuffix("/events")
        }.count == 1)
}

@Test func recognizedQuota403RetriesButAChangedInsertBodyFailsVerification() async throws {
    let (fixture, client, destination) = try await destinationSetup()
    await fixture.queue([
        .init(
            status: 403,
            data: Data("{\"error\":{\"errors\":[{\"reason\":\"userRateLimitExceeded\"}]}}".utf8))
    ])
    try await client.verifyDestination(destination)
    let key = try await client.prepareInsert(in: destination, content: content())
    let observed = try await client.insert(key)
    _ = try await client.update(observed, content: content(detailed: true))
    await #expect(throws: GoogleDestinationFailure.conflict) { try await client.verifyInsert(key) }
}

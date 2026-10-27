import Foundation

/// Internal to trusted Google infrastructure. Neither URLs nor bearer tokens cross the UI API.
struct GoogleCalendarLease: Sendable, Equatable {
    let authority: UUID
    let generation: UInt64
}
protocol GoogleCalendarSending: Sendable {
    func calendarLease() async throws -> GoogleCalendarLease
    func sendCalendar(_ request: URLRequest, lease: GoogleCalendarLease) async throws
        -> OAuthHTTPResponse
}

enum GoogleDestinationFailure: Error, Equatable, Sendable {
    case authorization, cancelled, invalidInput, invalidResponse, ownership, conflict, notFound
    case rateLimited, unavailable, outcomeUnknown, recoveryRequired, limitExceeded
}

/// Fixed API origin; opaque IDs are single encoded path components, never URLs or aliases.
enum GoogleCalendarRequest {
    static func make(
        method: String, calendar: String? = nil, event: String? = nil,
        events: Bool = false, query: [URLQueryItem] = [], body: Data? = nil, etag: String? = nil
    ) throws -> URLRequest {
        var parts = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars")!
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
        if let calendar {
            guard validCalendarID(calendar) else { throw GoogleDestinationFailure.invalidInput }
            parts.percentEncodedPath +=
                "/" + calendar.addingPercentEncoding(withAllowedCharacters: allowed)!
        }
        if events { parts.percentEncodedPath += "/events" }
        if let event {
            guard events, validEventID(event) else { throw GoogleDestinationFailure.invalidInput }
            parts.percentEncodedPath += "/" + event
        }
        if !query.isEmpty { parts.queryItems = query }
        var request = URLRequest(url: parts.url!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let etag {
            guard validETag(etag) else { throw GoogleDestinationFailure.invalidInput }
            request.setValue(etag, forHTTPHeaderField: "If-Match")
        }
        return request
    }
    static func validCalendarID(_ value: String) -> Bool {
        !value.isEmpty && value.lowercased() != "primary" && value.utf8.count <= 1024
            && value != "." && value != ".."
            && value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
    static func validEventID(_ value: String) -> Bool {
        (5...1024).contains(value.utf8.count)
            && value.utf8.allSatisfy { (48...57).contains($0) || (97...118).contains($0) }
    }
    static func validETag(_ value: String) -> Bool {
        value.count >= 3 && value.utf8.count <= 1024 && value.first == "\"" && value.last == "\""
            && value.dropFirst().dropLast().utf8.allSatisfy { $0 >= 33 && $0 <= 126 && $0 != 34 }
    }
}

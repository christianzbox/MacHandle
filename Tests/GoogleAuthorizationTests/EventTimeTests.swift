import Foundation
import Testing

@testable import GoogleAuthorization

@Test func timestampEncodingIsLosslessOrRejectedAndOffsetsCompareByInstant() throws {
    let parser = ISO8601DateFormatter()
    for base in [0.0, 1_794_132_000.0] {
        for fraction in [0.0, 0.125, 0.25, 0.5, 0.999] {
            let date = Date(timeIntervalSince1970: base + fraction)
            let encoded = try GoogleEventTime(instant: date)
            #expect(encoded.value == date)
            #expect(encoded.dateTime?.hasSuffix("Z") == true)
        }
    }
    let utc = try GoogleEventTime(instant: parser.date(from: "2026-11-01T05:30:00Z")!)
    let offset = try JSONDecoder().decode(
        GoogleEventTime.self, from: Data(#"{"dateTime":"2026-11-01T01:30:00-04:00"}"#.utf8))
    let repeated = try JSONDecoder().decode(
        GoogleEventTime.self, from: Data(#"{"dateTime":"2026-11-01T01:30:00-05:00"}"#.utf8))
    #expect(utc == offset && utc != repeated)
    for seconds in [1000.0001, .infinity, 253_402_300_800, -62_135_596_801] {
        #expect(throws: GoogleDestinationFailure.invalidInput) {
            try GoogleEventTime(instant: Date(timeIntervalSince1970: seconds))
        }
    }
}

@Test func allDayDatesRemainExclusiveAndDistinctFromMidnightInstants() throws {
    let start = try GoogleEventTime(day: "2026-03-07")
    let end = try GoogleEventTime(day: "2026-03-10")
    let content = try GoogleEventContent(start: start, end: end)
    #expect(content.start.date == "2026-03-07" && content.end.date == "2026-03-10")
    #expect(start != (try GoogleEventTime(instant: start.value!)))
    #expect(throws: GoogleDestinationFailure.invalidInput) {
        try GoogleEventTime(day: "2026-02-29")
    }
    #expect(throws: GoogleDestinationFailure.invalidInput) {
        try GoogleEventContent(start: end, end: end)
    }
}

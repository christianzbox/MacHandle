import AppleCalendarProvider
import CoreDomain
import EventKit
import Foundation
import Testing

@Test func eventKitAuthorizationMappingKeepsReadCapabilityDistinct() {
    #expect(EventKitCalendarProvider.mapAuthorization(.notDetermined) == .notDetermined)
    #expect(EventKitCalendarProvider.mapAuthorization(.denied) == .denied)
    #expect(EventKitCalendarProvider.mapAuthorization(.restricted) == .restricted)
    #expect(EventKitCalendarProvider.mapAuthorization(.writeOnly) == .writeOnly)
    #expect(EventKitCalendarProvider.mapAuthorization(.fullAccess) == .fullAccess)
}

@Test func eventKitChangeObservationDeliversSignalWithoutInitializingStore() async {
    let provider = EventKitCalendarProvider()
    let stream = await provider.changes()
    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    var iterator = stream.makeAsyncIterator()
    #expect(await iterator.next() != nil)
}

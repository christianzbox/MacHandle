/// Validates local identity consistency, not continuity across resyncs or installations.
public enum CalendarOccurrenceIdentity {
    private enum Family { case single, timed, allDay }

    public static func validate(_ references: Set<OccurrenceReference>) throws {
        var families: [CalendarReference: [EventID: Family]] = [:]
        for reference in references {
            let family: Family
            switch reference.originalAnchor {
            case .unknown: throw ProviderFailure.ambiguousIdentity
            case .notRecurring: family = .single
            case .timed: family = .timed
            case .allDay: family = .allDay
            }
            // A changed anchor kind cannot establish whether this is a new occurrence or
            // an edited existing one. Never create a second copy based on that guess.
            if let previous = families[reference.calendar]?[reference.item], previous != family {
                throw ProviderFailure.ambiguousIdentity
            }
            families[reference.calendar, default: [:]][reference.item] = family
        }
    }
}

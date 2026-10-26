import CoreDomain
import Foundation
import PermissionEngine

/// Trusted, synthetic-only composition. Each sample has its own simulated OS context.
/// These authorities must never be reused for a live provider or transport.
public actor PreviewPolicyService: PreviewEvaluating {
    private let authorities: [SampleConnection: PolicyAuthority]
    private var isEvaluating = false

    public init(google: PolicyAuthority, localMCP: PolicyAuthority) {
        authorities = [.google: google, .localMCP: localMCP]
    }

    public func evaluate(_ configuration: PreviewConfiguration) async -> PreviewOutcome {
        guard !isEvaluating else { return .busy }
        isEvaluating = true
        defer { isEvaluating = false }
        do {
            guard let authority = authorities[configuration.connection] else { return .unavailable }
            let id = try ConnectionID("preview-\(configuration.connection.rawValue)")
            let account = try AccountReference(
                provider: ProviderID("synthetic"), store: StoreID("preview-store"),
                account: AccountID("preview-account"))
            let calendars = try Set(
                configuration.calendars.map {
                    try CalendarReference(account: account, localID: DomainID($0.rawValue))
                })
            let fields: Set<CalendarField> =
                configuration.access == .availability
                ? [.time, .occupancy] : [.time, .occupancy, .status, .title, .location, .notes]
            let operation: CalendarOperation =
                configuration.access == .availability ? .checkAvailability : .readDetails
            let grants = Dictionary(
                uniqueKeysWithValues: calendars.map {
                    ($0, CalendarGrant(operations: [operation], readableFields: fields))
                })
            let state: ConnectionState
            switch configuration.state {
            case .disabled, .unconfigured, .unavailable: state = .disabled
            case .revoked: state = .revoked
            case .denied, .enabled: state = .enabled
            }
            await authority.observeOSPermissions(
                .init(calendars: configuration.state == .denied ? .denied : .fullAccess))
            // Replacing configuration invalidates old receipts; bind afresh below. Never cache allows.
            await authority.setConnection(
                Connection(
                    id: id, kind: configuration.connection == .google ? .googleSync : .localMCP,
                    state: state), policy: ConnectionPolicy(calendars: grants))
            switch configuration.state {
            case .disabled: return .disabled
            case .unconfigured: return .unconfigured
            case .unavailable: return .unavailable
            case .revoked: return .revoked
            case .denied: return .denied
            case .enabled: break
            }
            guard !calendars.isEmpty else { return .noSelection }
            let window = try InstantInterval(
                start: Instant(Date(timeIntervalSince1970: 0)),
                end: Instant(Date(timeIntervalSince1970: 3600)))
            let request = try CalendarReadRequest(calendars: calendars, window: window)
            let session = try await authority.bindTrustedConnection(id)
            switch await session.evaluate(
                .calendarRead(request, operation: operation, fields: fields))
            {
            case .allowed(let receipt):
                // This is a read-only preview. No write approval or provider dispatch is available.
                guard !receipt.requiresLocalApproval else { return .blocked }
                if case .allowed = await session.revalidate(receipt) { return .allowed }
                return .blocked
            case .denied: return .blocked
            }
        } catch {
            return .unavailable
        }
    }
}

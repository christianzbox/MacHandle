import Observation

/// Display-only state. Never carries credential values, raw provider errors, or account identity.
@MainActor @Observable
public final class GoogleConnectionModel {
    public private(set) var state: GoogleAuthenticationState = .disconnected
    public let isConfigured: Bool
    public private(set) var isBusy = false
    @ObservationIgnored private let service: GoogleAuthentication?
    @ObservationIgnored private var generation: UInt64 = 0

    public init(service: GoogleAuthentication? = nil) {
        self.service = service
        isConfigured = service != nil
    }
    public func connect() async {
        guard let service, !isBusy else { return }
        generation &+= 1
        let current = generation
        isBusy = true
        state = .authorizing
        await service.connect()
        let result = await service.status()
        if generation == current {
            state = result
            isBusy = false
        }
    }
    public func checkAuthorization() async {
        guard let service, !isBusy else { return }
        generation &+= 1
        let current = generation
        isBusy = true
        state = .refreshing
        await service.checkAuthorization()
        let result = await service.status()
        if generation == current {
            state = result
            isBusy = false
        }
    }
    public func cancel() async {
        guard let service else { return }
        generation &+= 1
        let current = generation
        await service.cancelSignIn()
        let result = await service.status()
        if generation == current {
            state = result
            isBusy = false
        }
    }
    public func disconnect(revokeGoogleGrant: Bool = false) async {
        guard let service, state != .disconnecting else { return }
        generation &+= 1
        let current = generation
        isBusy = true
        state = .disconnecting
        await service.disconnect(revokeGoogleGrant: revokeGoogleGrant)
        let result = await service.status()
        if generation == current {
            state = result
            isBusy = false
        }
    }
}

import Observation
import ServiceManagement

public enum LoginItemStatus: Sendable, Equatable {
    case disabled, enabled, requiresApproval, unavailable
}

@MainActor
protocol LoginItemServicing: AnyObject {
    var status: LoginItemStatus { get }
    func enable() throws
    func disable() async throws
}

@MainActor
private final class SystemLoginItem: LoginItemServicing {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: .disabled
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
    func enable() throws { try SMAppService.mainApp.register() }
    func disable() async throws { try await SMAppService.mainApp.unregister() }
}

/// System registration is the source of truth. No startup registration or parallel preference bit.
@Observable @MainActor
public final class LoginItemModel {
    public private(set) var status: LoginItemStatus
    public private(set) var busy = false
    public private(set) var failed = false
    private let service: any LoginItemServicing

    public convenience init() { self.init(service: SystemLoginItem()) }
    init(service: any LoginItemServicing) {
        self.service = service
        status = service.status
    }
    public var requested: Bool { status == .enabled || status == .requiresApproval }
    public func refresh() { status = service.status }
    public func setEnabled(_ enabled: Bool) async {
        guard !busy else { return }
        refresh()
        guard status != .unavailable, enabled != requested else { return }
        busy = true
        failed = false
        defer {
            refresh()
            busy = false
        }
        do {
            if enabled { try service.enable() } else { try await service.disable() }
        } catch { failed = true }
    }
}

import Observation

public protocol PreviewEvaluating: Sendable {
    func evaluate(_ configuration: PreviewConfiguration) async -> PreviewOutcome
}

/// Owns UI state only. Evaluation is injected; there is no provider or authority handle here.
@MainActor @Observable
public final class ConnectionPreviewStore {
    public private(set) var previews: [ConnectionPreview]
    public private(set) var activity: [PreviewActivity] = []
    public private(set) var isUpdating = false
    @ObservationIgnored private let evaluator: any PreviewEvaluating
    @ObservationIgnored private var sequence = 0

    public init(evaluator: any PreviewEvaluating) {
        self.evaluator = evaluator
        previews = SampleConnection.allCases.map {
            ConnectionPreview(
                configuration: PreviewConfiguration(connection: $0), outcome: .disabled)
        }
    }

    public var enabledPreviewCount: Int {
        previews.filter { $0.configuration.state == .enabled }.count
    }

    /// One accepted configuration change at a time. Old allows disappear before any suspension.
    /// All scenes share this store and disable controls while the evaluation is pending.
    @discardableResult
    public func apply(_ configuration: PreviewConfiguration) async -> Bool {
        guard !isUpdating,
            let index = previews.firstIndex(where: { $0.id == configuration.connection })
        else {
            return false
        }
        isUpdating = true
        previews[index] = ConnectionPreview(configuration: configuration, outcome: nil)
        let outcome = await evaluator.evaluate(configuration)
        previews[index] = ConnectionPreview(configuration: configuration, outcome: outcome)
        sequence += 1
        activity.insert(
            PreviewActivity(
                id: sequence, connection: configuration.connection, state: configuration.state,
                outcome: outcome), at: 0)
        activity = Array(activity.prefix(20))
        isUpdating = false
        return true
    }

    public func clearActivity() { activity = [] }
}

@MainActor @Observable
public final class ApplicationState {
    public var section: AppSection? = .overview
    public var selectedConnection: SampleConnection = .google
    public var appearance: AppAppearance = .system
    public let connections: ConnectionPreviewStore

    public init(connections: ConnectionPreviewStore) { self.connections = connections }

    public func showConnection(_ connection: SampleConnection) {
        selectedConnection = connection
        section = .connections
    }
}

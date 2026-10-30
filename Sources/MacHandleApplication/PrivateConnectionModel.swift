import Foundation
import NativeMCPBridge
import Observation

/// Private sample app presentation. No live provider or permission factory exists in this app target.
@Observable @MainActor
public final class PrivateConnectionModel {
    public enum Phase: Sendable { case idle, listening, review, connected, closed, unavailable }
    public private(set) var phase: Phase = .idle
    public private(set) var reviewID: UUID?
    private var bridge: PrivateSampleBridge?
    private var generation = UUID()
    public init() {}
    public func start() {
        guard phase == .idle else { return }
        let expected = generation
        do {
            bridge = try PrivateSampleBridge { [weak self] state in
                guard let self, self.generation == expected else { return }
                self.reviewID = nil
                switch state {
                case .listening: self.phase = .listening
                case .review(let id):
                    self.phase = .review
                    self.reviewID = id
                case .connected: self.phase = .connected
                case .closed: self.phase = .closed
                case .unavailable: self.phase = .unavailable
                }
            }
        } catch { phase = .unavailable }
    }
    public func approve() async {
        guard phase == .review, let id = reviewID else { return }
        reviewID = nil
        await bridge?.approve(id)
    }
    public func stop() async {
        generation = UUID()
        let old = bridge
        bridge = nil
        reviewID = nil
        phase = .closed
        await old?.stop()
    }
}

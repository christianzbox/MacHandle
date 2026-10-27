import Foundation
import Testing

@testable import GoogleAuthorization

@Test func syntheticLoopbackAcceptsOneMatchingResponseAndRejectsWrongState() async throws {
    let receiver = LoopbackAuthorization(attempt: attempt, timeout: .seconds(10))
    let local = try await receiver.start()
    #expect(local.host == "127.0.0.1" && local.port != 0)
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    do {
        let wrong = URL(string: local.absoluteString + "?state=wrong&code=synthetic")!
        let (_, rejected) = try await session.data(from: wrong)
        #expect((rejected as? HTTPURLResponse)?.statusCode == 400)
        let valid = URL(
            string: local.absoluteString + "?state=synthetic-state&code=synthetic-loopback")!
        let (_, accepted) = try await session.data(from: valid)
        #expect((accepted as? HTTPURLResponse)?.statusCode == 200)
        #expect(try await receiver.waitForCode() == "synthetic-loopback")
        await #expect(throws: GoogleAuthFailure.cancelled) { try await receiver.start() }
    } catch {
        await receiver.cancel()
        throw error
    }
}

@Test func loopbackTimeoutAndCancellationClosePendingAttempts() async throws {
    let timed = LoopbackAuthorization(attempt: attempt, timeout: .seconds(1))
    _ = try await timed.start()
    await #expect(throws: GoogleAuthFailure.timedOut) { try await timed.waitForCode() }
    let cancelled = LoopbackAuthorization(attempt: attempt)
    _ = try await cancelled.start()
    await cancelled.cancel()
    await #expect(throws: GoogleAuthFailure.cancelled) { try await cancelled.waitForCode() }
    let beforeStart = LoopbackAuthorization(attempt: attempt)
    await beforeStart.cancel()
    await #expect(throws: GoogleAuthFailure.cancelled) { try await beforeStart.start() }
}

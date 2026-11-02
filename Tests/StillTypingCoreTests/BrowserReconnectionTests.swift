import Foundation
import Testing
@testable import StillTypingCore

private let reconnectEpoch = Date(timeIntervalSince1970: 0)

@Test func automaticRecoveryOnlyTargetsChosenRunningBrowsers() {
    var reconnection = BrowserReconnection(remembered: [.safari])
    #expect(reconnection.isDue(.safari, processIdentifier: nil, now: reconnectEpoch) == false)
    #expect(reconnection.isDue(.chrome, processIdentifier: 200, now: reconnectEpoch) == false)
    #expect(reconnection.isDue(.safari, processIdentifier: 100, now: reconnectEpoch))
    reconnection.remember(.chrome)
    #expect(reconnection.remembered == [.safari, .chrome])
    #expect(reconnection.isDue(.chrome, processIdentifier: 200, now: reconnectEpoch))
}

@Test func transientFailuresBackOffAndKeepRetrying() {
    var reconnection = BrowserReconnection(remembered: [.safari])
    var now = reconnectEpoch
    for delay in [1.0, 2, 4, 8, 16, 30, 30] {
        reconnection.failed(.safari, processIdentifier: 100, now: now)
        #expect(!reconnection.isDue(.safari, processIdentifier: 100, now: now.addingTimeInterval(delay - 0.1)))
        now.addTimeInterval(delay)
        #expect(reconnection.isDue(.safari, processIdentifier: 100, now: now))
    }
    #expect(reconnection.remembered == [.safari])
}

@Test func reopeningOrActivatingABrowserBypassesTheOldRetryDelay() {
    var reconnection = BrowserReconnection(remembered: [.safari])
    reconnection.failed(.safari, processIdentifier: 100, now: reconnectEpoch)
    #expect(!reconnection.isDue(.safari, processIdentifier: nil, now: reconnectEpoch))
    #expect(reconnection.isDue(.safari, processIdentifier: 101, now: reconnectEpoch))
    reconnection.failed(.safari, processIdentifier: 101, now: reconnectEpoch)
    #expect(!reconnection.isDue(.safari, processIdentifier: 101, now: reconnectEpoch))
    reconnection.retryNow(.safari)
    #expect(reconnection.isDue(.safari, processIdentifier: 101, now: reconnectEpoch))
}

@Test func reconnectsSharePollingWithoutStarvingActiveProtection() {
    var polling = BrowserPolling()
    var recovered: Set<BrowserKind> = []
    for _ in 0..<2 {
        // Safari is connected; Chrome and Arc are eligible to reconnect.
        let targets = polling.next(connected: [.safari, .chrome, .arc], frontmost: .safari, protectionEnabled: true)
        #expect(targets.first == .safari)
        recovered.formUnion(targets.dropFirst())
    }
    #expect(recovered == [.chrome, .arc])
    let pausedTargets = polling.next(connected: [.chrome], frontmost: .chrome, protectionEnabled: false)
    #expect(pausedTargets == [.chrome])
}

import Foundation

/// Remembers the user's browser choices separately from a live process connection.
public struct BrowserReconnection: Sendable {
    private struct Retry: Sendable {
        var processIdentifier: Int32
        var failures: Int
        var nextAttempt: Date
    }

    public private(set) var remembered: Set<BrowserKind>
    private var retries: [BrowserKind: Retry] = [:]

    public init(remembered: Set<BrowserKind> = []) {
        self.remembered = remembered
    }

    public mutating func remember(_ browser: BrowserKind) {
        remembered.insert(browser)
        retries[browser] = nil
    }

    public mutating func retryNow(_ browser: BrowserKind) {
        retries[browser] = nil
    }

    public func isDue(_ browser: BrowserKind, processIdentifier: Int32?, now: Date) -> Bool {
        guard remembered.contains(browser), let processIdentifier else { return false }
        guard let retry = retries[browser], retry.processIdentifier == processIdentifier else { return true }
        return now >= retry.nextAttempt
    }

    public mutating func failed(_ browser: BrowserKind, processIdentifier: Int32, now: Date) {
        let failures = if let previous = retries[browser], previous.processIdentifier == processIdentifier {
            previous.failures
        } else { 0 }
        let delay = min(pow(2, Double(failures)), 30)
        retries[browser] = Retry(processIdentifier: processIdentifier, failures: min(failures + 1, 5),
                                 nextAttempt: now.addingTimeInterval(delay))
    }
}

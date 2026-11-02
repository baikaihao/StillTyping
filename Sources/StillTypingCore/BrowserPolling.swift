public struct BrowserPolling: Sendable {
    private var nextBackground = 0
    public init() {}

    /// Renew the front browser first; rotate one background probe to bound each sweep.
    public mutating func next(connected: [BrowserKind], frontmost: BrowserKind?, protectionEnabled: Bool) -> [BrowserKind] {
        let foreground = protectionEnabled ? connected.first(where: { $0 == frontmost }) : nil
        let background = connected.filter { $0 != foreground }
        guard !background.isEmpty else { return foreground.map { [$0] } ?? [] }
        let candidate = background[nextBackground % background.count]
        nextBackground = (nextBackground % background.count + 1) % background.count
        return (foreground.map { [$0] } ?? []) + [candidate]
    }
}

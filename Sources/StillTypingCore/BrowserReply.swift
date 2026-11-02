import Foundation

public enum BrowserPageState: String, Decodable, Sendable {
    case ready, open, unsupported
    case notRunning = "not-running"
    case noWindow = "no-window"
}

public enum BrowserReply {
    private struct Packet: Decodable { let state: BrowserPageState }

    public static func state(from response: String) -> BrowserPageState? {
        let decoder = JSONDecoder()
        let data = Data(response.utf8)
        if let packet = try? decoder.decode(Packet.self, from: data) { return packet.state }
        // Arc can JSON-encode a JavaScript string result one additional time.
        guard let nested = try? decoder.decode(String.self, from: data) else { return nil }
        return (try? decoder.decode(Packet.self, from: Data(nested.utf8)))?.state
    }
}

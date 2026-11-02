import Foundation
import Testing
@testable import StillTypingCore

private let dictionary = """
<dictionary><suite name="Browser" code="TEST">
  <class name="window" code="cwin"><property name="active tab" code="acTa" type="tab"/></class>
  <command name="execute" code="CrSuExJa"><direct-parameter type="specifier"/>
    <parameter name="javascript" code="JvSc" type="text"/>
  </command>
</suite></dictionary>
"""

@Test func scriptingCodesComeFromTheSelectedBrowser() throws {
    #expect(BrowserScriptingDefinition(data: Data(dictionary.utf8)) == .chromium)
    let custom = dictionary.replacingOccurrences(of: "CrSuExJa", with: "ARCrExJS")
        .replacingOccurrences(of: "acTa", with: "curr")
        .replacingOccurrences(of: "JvSc", with: "jscp")
    let vocabulary = try #require(BrowserScriptingDefinition(data: Data(custom.utf8)))
    let source = BrowserScript.execute("void 0", in: .arc, vocabulary: vocabulary)
    #expect(source.contains("«event ARCrExJS»"))
    #expect(source.contains("«class curr»"))
    #expect(source.contains("«class jscp»"))
    #expect(!source.contains("com.google.Chrome"))
}

@Test func incompatibleDictionariesAreRejected() {
    #expect(BrowserScriptingDefinition(data: Data("<dictionary/>".utf8)) == nil)
    let noParameter = dictionary.replacingOccurrences(of: "name=\"javascript\"", with: "name=\"other\"")
    #expect(BrowserScriptingDefinition(data: Data(noParameter.utf8)) == nil)
    let invalid = dictionary.replacingOccurrences(of: "CrSuExJa", with: "not-an-event-code")
    #expect(BrowserScriptingDefinition(data: Data(invalid.utf8)) == nil)
}

@Test func browserRepliesAcceptPlainAndArcEncodedJSON() throws {
    let plain = "{\"state\":\"ready\"}"
    let arc = String(decoding: try JSONEncoder().encode(plain), as: UTF8.self)
    #expect(BrowserReply.state(from: plain) == .ready)
    #expect(BrowserReply.state(from: arc) == .ready)
    #expect(BrowserReply.state(from: "{\"state\":\"no-window\"}") == .noWindow)
    for malformed in ["", "undefined", "null", "true", "{}", "{\"state\":\"unexpected\"}"] {
        #expect(BrowserReply.state(from: malformed) == nil)
    }
}

@Test func backgroundChecksDoNotStarveTheFrontBrowser() {
    let connected = BrowserKind.allCases
    var polling = BrowserPolling()
    var background: Set<BrowserKind> = []
    for _ in 0..<(connected.count - 1) {
        let targets = polling.next(connected: connected, frontmost: .chrome, protectionEnabled: true)
        #expect(targets.count == 2)
        #expect(targets.first == .chrome)
        background.formUnion(targets.dropFirst())
    }
    #expect(background == Set(connected.filter { $0 != .chrome }))
}

@Test func connectionMonitoringContinuesWhileProtectionIsOff() {
    var polling = BrowserPolling()
    var checked: Set<BrowserKind> = []
    for _ in BrowserKind.allCases {
        let targets = polling.next(connected: BrowserKind.allCases, frontmost: .chrome, protectionEnabled: false)
        #expect(targets.count == 1)
        checked.formUnion(targets)
    }
    #expect(checked == Set(BrowserKind.allCases))
    #expect(polling.next(connected: [], frontmost: .chrome, protectionEnabled: true).isEmpty)
    #expect(polling.next(connected: [.arc], frontmost: .arc, protectionEnabled: true) == [.arc])
}

@Test func browserIdentifiersAreUnique() {
    #expect(Set(BrowserKind.allCases.map(\.bundleID)).count == BrowserKind.allCases.count)
    #expect(Set(BrowserKind.allCases) == [.safari, .chrome, .edge, .arc, .brave, .vivaldi, .opera])
}

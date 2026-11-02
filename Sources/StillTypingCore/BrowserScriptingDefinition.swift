import Foundation

/// The small scripting surface used by StillTyping, read from the installed browser.
public struct BrowserScriptingDefinition: Sendable, Equatable {
    public let execute: String
    public let javascript: String
    public let activeTab: String
    public let window: String

    // Chromium's published scripting.sdef, also used for offline compilation tests.
    public static let chromium = Self(execute: "CrSuExJa", javascript: "JvSc", activeTab: "acTa", window: "cwin")

    private init(execute: String, javascript: String, activeTab: String, window: String) {
        self.execute = execute
        self.javascript = javascript
        self.activeTab = activeTab
        self.window = window
    }

    public init?(data: Data) {
        let delegate = DefinitionParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let execute = delegate.execute, let javascript = delegate.javascript,
              let activeTab = delegate.activeTab else { return nil }
        self.init(execute: execute, javascript: javascript, activeTab: activeTab, window: delegate.window ?? "cwin")
    }
}

private final class DefinitionParser: NSObject, XMLParserDelegate {
    var execute: String?
    var javascript: String?
    var activeTab: String?
    var window: String?
    private var inExecute = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String]) {
        let name = attributes["name"]?.lowercased()
        let code = attributes["code"]
        if elementName == "command" {
            inExecute = name == "execute" && valid(code, length: 8)
            if inExecute { execute = code }
        } else if elementName == "parameter", inExecute, name == "javascript", valid(code, length: 4) {
            javascript = code
        } else if elementName == "property", name == "active tab", valid(code, length: 4) {
            activeTab = code
        } else if elementName == "class", name == "window", valid(code, length: 4) {
            window = code
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "command" { inExecute = false }
    }

    private func valid(_ value: String?, length: Int) -> Bool {
        guard let value else { return false }
        return value.utf8.count == length && value.utf8.allSatisfy { (32...126).contains($0) }
    }
}

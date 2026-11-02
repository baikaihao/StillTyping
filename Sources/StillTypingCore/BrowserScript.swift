import Foundation

public enum BrowserKind: String, CaseIterable, Sendable, Identifiable {
    case safari, chrome, edge, arc, brave, vivaldi, opera
    public var id: String { rawValue }
    public var isPrimary: Bool { self == .safari || self == .chrome }
    public var name: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        case .edge: "Microsoft Edge"
        case .arc: "Arc"
        case .brave: "Brave"
        case .vivaldi: "Vivaldi"
        case .opera: "Opera"
        }
    }
    public var bundleID: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        case .edge: "com.microsoft.edgemac"
        case .arc: "company.thebrowser.Browser"
        case .brave: "com.brave.Browser"
        case .vivaldi: "com.vivaldi.Vivaldi"
        case .opera: "com.operasoftware.Opera"
        }
    }
}

public enum BrowserScript {
    public static func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n") + "\""
    }

    public static func execute(_ javascript: String, in browser: BrowserKind,
                               vocabulary: BrowserScriptingDefinition = .chromium) -> String {
        if browser == .safari {
            return safariCommand("return do JavaScript \(literal(javascript)) in current tab of front window")
        }
        let command = "return «event \(vocabulary.execute)» (get «class \(vocabulary.activeTab)» of currentWindow) given «class \(vocabulary.javascript)»: \(literal(javascript))"
        return scriptedBrowser(browser, vocabulary: vocabulary, command: command)
    }

    public static func windowState(in browser: BrowserKind,
                                   vocabulary: BrowserScriptingDefinition = .chromium) -> String {
        let command = "return \(literal("{\"state\":\"open\"}"))"
        return browser == .safari ? safariCommand(command)
            : scriptedBrowser(browser, vocabulary: vocabulary, command: command)
    }

    private static func safariCommand(_ command: String) -> String {
        """
        with timeout of 2 seconds
            if application id "com.apple.Safari" is not running then return \(literal("{\"state\":\"not-running\"}"))
            tell application id "com.apple.Safari"
                if (count of windows) is 0 then return \(literal("{\"state\":\"no-window\"}"))
                \(command)
            end tell
        end timeout
        """
    }

    private static func scriptedBrowser(_ browser: BrowserKind, vocabulary: BrowserScriptingDefinition, command: String) -> String {
        // A variable target and raw event codes compile without another browser's dictionary.
        // Some Arc versions retain closed windows; only select one with an accessible active tab.
        """
        set browserBundleID to \(literal(browser.bundleID))
        with timeout of 2 seconds
            if application id browserBundleID is not running then return \(literal("{\"state\":\"not-running\"}"))
            tell application id browserBundleID
                set currentWindow to missing value
                repeat with candidate in every «class \(vocabulary.window)»
                    try
                        set currentTab to get «class \(vocabulary.activeTab)» of candidate
                        if currentTab is not missing value then
                            set currentWindow to contents of candidate
                            exit repeat
                        end if
                    end try
                end repeat
                if currentWindow is missing value then return \(literal("{\"state\":\"no-window\"}"))
                \(command)
            end tell
        end timeout
        """
    }

    public static func bootstrap(source: String, owner: String, enabled: Bool) -> String {
        // Encoding a String with the default JSONEncoder cannot fail.
        let encodedOwner = String(decoding: try! JSONEncoder().encode(owner), as: UTF8.self)
        return """
        (() => {
          if (!/^https?:$/.test(location.protocol)) return JSON.stringify({state:"unsupported"});
          \(source)
          globalThis.StillTypingGuardFactory(window, {
            owner: \(encodedOwner), enabled: \(enabled), leaseMilliseconds: 4000
          });
          return JSON.stringify({state:"ready"});
        })()
        """
    }

    public static let disable = """
    (() => {
      const guard = window.__stillTypingGuard_v1;
      if (guard && guard.version === 1) guard.configure({enabled:false});
      return JSON.stringify({state:"paused"});
    })()
    """
}

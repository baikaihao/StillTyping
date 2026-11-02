import AppKit
import StillTypingCore

nonisolated enum AutomationResult: Sendable {
    case success(String)
    case failure(code: Int, message: String)
}

/// Serialized off the UI actor. Each generated script bounds outbound Apple Events.
actor BrowserAutomation {
    private var compiledScripts: [String: NSAppleScript] = [:]
    private var scriptingDefinitions: [Int32: BrowserScriptingDefinition] = [:]
    @MainActor static func prepareRuntime() {
        // Initialize AppleScript on the main thread for older macOS/XProtect versions.
        // This local constant script does not contact any application or ask for permissions.
        var error: NSDictionary?
        _ = NSAppleScript(source: "return true")?.executeAndReturnError(&error)
    }

    func execute(_ javascript: String, browser: BrowserKind, processIdentifier: Int32) -> AutomationResult {
        perform(javascript: javascript, browser: browser, processIdentifier: processIdentifier)
    }

    func windowState(browser: BrowserKind, processIdentifier: Int32) -> AutomationResult {
        perform(javascript: nil, browser: browser, processIdentifier: processIdentifier)
    }

    private func perform(javascript: String?, browser: BrowserKind, processIdentifier: Int32) -> AutomationResult {
        // Queued work must never reconnect to a new browser process or relaunch a closed browser.
        guard let application = NSRunningApplication(processIdentifier: processIdentifier),
              !application.isTerminated, application.bundleIdentifier == browser.bundleID else {
            return .success("{\"state\":\"not-running\"}")
        }
        let vocabulary: BrowserScriptingDefinition
        if browser == .safari {
            vocabulary = .chromium // Safari uses its own system dictionary.
        } else if let definition = scriptingDefinition(for: application) {
            vocabulary = definition
        } else {
            return .failure(code: -1, message: L10n.format("%@ does not provide a compatible page scripting interface. Update the browser and try again.", browser.name))
        }
        let source = if let javascript {
            BrowserScript.execute(javascript, in: browser, vocabulary: vocabulary)
        } else {
            BrowserScript.windowState(in: browser, vocabulary: vocabulary)
        }
        guard let script = compiledScripts[source] ?? NSAppleScript(source: source) else {
            return .failure(code: -1, message: L10n.text("Could not create the browser connection script."))
        }
        compiledScripts[source] = script
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            return .failure(code: error[NSAppleScript.errorNumber] as? Int ?? -1,
                            message: error[NSAppleScript.errorMessage] as? String ?? L10n.text("The browser did not respond."))
        }
        return .success(descriptor.stringValue ?? "")
    }

    private func scriptingDefinition(for application: NSRunningApplication) -> BrowserScriptingDefinition? {
        let pid = application.processIdentifier
        if let cached = scriptingDefinitions[pid] { return cached }
        guard let url = application.bundleURL, let bundle = Bundle(url: url) else { return nil }
        var urls: [URL] = []
        if let name = bundle.object(forInfoDictionaryKey: "OSAScriptingDefinition") as? String,
           let resourceURL = bundle.resourceURL {
            urls.append(resourceURL.appendingPathComponent(name))
        }
        urls += bundle.urls(forResourcesWithExtension: "sdef", subdirectory: nil) ?? []
        for url in urls {
            if let data = try? Data(contentsOf: url), let definition = BrowserScriptingDefinition(data: data) {
                scriptingDefinitions[pid] = definition
                return definition
            }
        }
        return nil
    }
}

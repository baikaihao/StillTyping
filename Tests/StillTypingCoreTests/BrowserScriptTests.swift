import Testing
import Foundation
@testable import StillTypingCore

@Test func quotesCodeAsAppleScriptData() {
    #expect(BrowserScript.literal("a\"b\\c\nd\r") == "\"a\\\"b\\\\c\\nd\\r\"")
    #expect(BrowserScript.literal("$(touch /tmp/no) `id`") == "\"$(touch /tmp/no) `id`\"")
}

@Test(arguments: BrowserKind.allCases)
func targetsOnlyTheSelectedBrowserAndBoundsExecution(_ browser: BrowserKind) throws {
    let script = BrowserScript.execute("window.example = 'hello'", in: browser)
    #expect(script.contains("with timeout of 2 seconds"))
    #expect(script.contains(browser.bundleID))
    #expect(script.contains("no-window"))
    #expect(!script.contains("System Events"))
    #expect(!script.contains("do shell script"))
}

@Test func injectedProtectionHasALeaseAndNoContentCollection() {
    let script = BrowserScript.bootstrap(source: "/*guard source*/", owner: "test\"owner", enabled: false)
    #expect(script.contains("leaseMilliseconds: 4000"))
    #expect(script.contains("enabled: false"))
    #expect(script.contains("/^https?:$/"))
    #expect(!script.contains("document.body"))
    #expect(!script.contains("clipboard"))
}

@Test(arguments: BrowserKind.allCases)
func closedBrowsersAreCheckedBeforeSendingCommands(_ browser: BrowserKind) throws {
    for script in [BrowserScript.execute("void 0", in: browser), BrowserScript.windowState(in: browser)] {
        let runningCheck = try #require(script.range(of: "is not running"))
        let tell = try #require(script.range(of: "tell application id"))
        #expect(runningCheck.lowerBound < tell.lowerBound)
        #expect(script.contains("not-running"))
        #expect(script.contains("no-window"))
    }
    let probe = BrowserScript.windowState(in: browser)
    #expect(!probe.contains("do JavaScript"))
    #expect(!probe.contains("javascript"))
}

@Test(arguments: BrowserKind.allCases)
@MainActor func browserCommandsCompileWithoutExecuting(_ browser: BrowserKind) throws {
    for source in [BrowserScript.execute("void 0", in: browser), BrowserScript.windowState(in: browser)] {
        let script = try #require(NSAppleScript(source: source))
        var error: NSDictionary?
        let compiled = script.compileAndReturnError(&error)
        #expect(compiled, "\(String(describing: error))")
    }
}

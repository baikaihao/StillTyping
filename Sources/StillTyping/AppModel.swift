import AppKit
import Observation
import StillTypingCore

@Observable
final class AppModel {
    struct Connection: Identifiable {
        let browser: BrowserKind
        var id: BrowserKind { browser }
        var connected = false
        var status = L10n.text("Not connected")
        var lastError = ""
        var processIdentifier: Int32?
    }

    private(set) var protectionEnabled = true
    private(set) var hideDockIcon = UserDefaults.standard.bool(forKey: AppPresentation.hideDockIconKey)
    private(set) var isBusy = false
    private(set) var connections = BrowserKind.allCases.map { Connection(browser: $0) }
    private(set) var pageStatus = L10n.text("Waiting for a browser connection")
    let loginItem = LoginItemSettings()
    var labProtectionEnabled = true
    var labSubmitCount = 0
    var labPhase = "keydown"
    var labIsComposing = false
    var resetLab: (() -> Void)?
    private let automation = BrowserAutomation()
    private let owner = UUID().uuidString
    private static let rememberedBrowsersKey = "automaticallyReconnectBrowsers"
    private var reconnection = BrowserReconnection(remembered: Set(
        (UserDefaults.standard.stringArray(forKey: rememberedBrowsersKey) ?? []).compactMap(BrowserKind.init(rawValue:))
    ))
    private var timer: Timer?
    private var workspaceObservers: [any NSObjectProtocol] = []
    private var generation = 0
    private var lastAck: (browser: BrowserKind, date: Date)?
    private var polling = BrowserPolling()
    var connectedCount: Int { connections.filter(\.connected).count }

    init() {
        BrowserAutomation.prepareRuntime()
        for name in [NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] notification in
                let bundleIdentifier = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if name != NSWorkspace.didTerminateApplicationNotification,
                       let browser = BrowserKind.allCases.first(where: { $0.bundleID == bundleIdentifier }) {
                        self.reconnection.retryNow(browser)
                    }
                    self.refresh()
                    self.poll()
                }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(); self?.poll() }
        }
        // Migrate existing grants once, so an update does not require another manual connection.
        if UserDefaults.standard.object(forKey: Self.rememberedBrowsersKey) == nil {
            isBusy = true
            Task {
                defer { isBusy = false; refresh(); poll() }
                for browser in BrowserKind.allCases {
                    guard let pid = runningProcessIdentifier(browser) else { continue }
                    if await automation.hasPermission(browser: browser, processIdentifier: pid) {
                        reconnection.remember(browser)
                    }
                }
                saveRememberedBrowsers()
            }
        }
    }

    func refresh() {
        for connection in connections where connection.connected {
            guard let pid = connection.processIdentifier, isRunning(connection.browser, pid: pid) else {
                disconnect(connection.browser, status: L10n.text("Browser closed"))
                continue
            }
        }
        guard protectionEnabled else { pageStatus = L10n.text("Protection is off"); return }
        guard connectedCount > 0 else { pageStatus = L10n.text("Waiting for a browser connection"); return }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let ack = lastAck, ack.browser.bundleID == front, Date().timeIntervalSince(ack.date) < 2 {
            pageStatus = L10n.format("%@ connection is responsive", ack.browser.name)
        } else if connections.contains(where: { $0.connected && $0.browser.bundleID == front }) {
            pageStatus = L10n.text("Checking the current page…")
        } else {
            pageStatus = L10n.text("Waiting for a connected browser to become active")
        }
    }

    func connect(_ browser: BrowserKind) {
        guard !isBusy else { return }
        reconnection.remember(browser)
        saveRememberedBrowsers()
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleID)
            .first(where: { !$0.isTerminated }) else {
            disconnect(browser, status: L10n.text("Open the browser first"))
            refresh()
            return
        }
        guard let javascript = protectionScript(enabled: protectionEnabled) else {
            disconnect(browser, status: L10n.text("Protection resources are missing"), error: L10n.text("Rebuild the app"))
            refresh()
            return
        }
        let pid = application.processIdentifier
        let requestGeneration = generation
        let enabled = protectionEnabled
        update(browser, connected: false, status: L10n.text("Connecting…"))
        isBusy = true
        Task {
            defer { isBusy = false; refresh() }
            let result = await automation.execute(javascript, browser: browser, processIdentifier: pid, allowPermissionPrompt: true)
            receive(result, browser: browser, pid: pid, installing: enabled && requestGeneration == generation)
            recordConnectionAttempt(result, browser: browser, pid: pid)
            // Connecting can finish after the user changes the switch. Keep their latest choice.
            if requestGeneration != generation && !protectionEnabled {
                _ = await automation.execute(BrowserScript.disable, browser: browser, processIdentifier: pid)
            }
        }
    }

    func setDockIconHidden(_ hidden: Bool) {
        guard AppPresentation.setDockIconHidden(hidden) else { return }
        hideDockIcon = hidden
        UserDefaults.standard.set(hidden, forKey: AppPresentation.hideDockIconKey)
    }

    func setProtection(_ enabled: Bool) {
        protectionEnabled = enabled
        generation += 1
        lastAck = nil
        if enabled {
            poll()
        } else {
            for connection in connections where connection.connected {
                guard let pid = connection.processIdentifier else { continue }
                let browser = connection.browser
                Task { _ = await automation.execute(BrowserScript.disable, browser: browser, processIdentifier: pid) }
            }
        }
        refresh()
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        generation += 1
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func poll() {
        guard !isBusy else { return }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let now = Date()
        let eligible = connections.filter {
            $0.connected || reconnection.isDue($0.browser, processIdentifier: runningProcessIdentifier($0.browser), now: now)
        }
        let targets = polling.next(connected: eligible.map(\.browser),
                                   frontmost: BrowserKind.allCases.first(where: { $0.bundleID == front }),
                                   protectionEnabled: protectionEnabled)
        let selected = targets.compactMap { browser in eligible.first(where: { $0.browser == browser }) }
        guard !selected.isEmpty else { return }
        let requestGeneration = generation
        isBusy = true
        Task {
            defer { isBusy = false; refresh() }
            for connection in selected {
                guard requestGeneration == generation else { return }
                let browser = connection.browser
                guard let pid = connection.processIdentifier ?? runningProcessIdentifier(browser) else { continue }
                if connection.connected {
                    guard connections.contains(where: { $0.browser == browser && $0.connected && $0.processIdentifier == pid }) else { continue }
                } else {
                    update(browser, connected: false, status: L10n.text("Reconnecting…"))
                }
                let installing = protectionEnabled && connection.browser.bundleID == front
                let result: AutomationResult
                if installing || !connection.connected {
                    guard let javascript = protectionScript(enabled: installing) else {
                        disconnect(connection.browser, status: L10n.text("Protection resources are missing"), error: L10n.text("Rebuild the app"))
                        reconnection.failed(browser, processIdentifier: pid, now: Date())
                        continue
                    }
                    result = await automation.execute(javascript, browser: connection.browser, processIdentifier: pid)
                } else {
                    result = await automation.windowState(browser: connection.browser, processIdentifier: pid)
                }
                guard requestGeneration == generation else {
                    if installing && !protectionEnabled {
                        _ = await automation.execute(BrowserScript.disable, browser: browser, processIdentifier: pid)
                    }
                    return
                }
                // A browser may have quit while its Apple Event was in flight.
                if connection.connected {
                    guard connections.contains(where: { $0.browser == browser && $0.connected && $0.processIdentifier == pid }) else { continue }
                }
                receive(result, browser: connection.browser, pid: pid, installing: installing)
                recordConnectionAttempt(result, browser: browser, pid: pid)
            }
        }
    }

    private func runningProcessIdentifier(_ browser: BrowserKind) -> Int32? {
        NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleID)
            .first(where: { !$0.isTerminated })?.processIdentifier
    }

    private func saveRememberedBrowsers() {
        UserDefaults.standard.set(reconnection.remembered.map(\.rawValue).sorted(), forKey: Self.rememberedBrowsersKey)
    }

    private func recordConnectionAttempt(_ result: AutomationResult, browser: BrowserKind, pid: Int32) {
        if connections.contains(where: { $0.browser == browser && $0.connected }) {
            reconnection.retryNow(browser)
        } else if case .success(let response) = result, BrowserReply.state(from: response) == .noWindow {
            // Closing the last window leaves some browsers running. Check again on the next sweep.
            reconnection.retryNow(browser)
        } else {
            reconnection.failed(browser, processIdentifier: pid, now: Date())
        }
    }

    private func protectionScript(enabled: Bool) -> String? {
        guard let url = AppResources.url(forResource: "guard", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return BrowserScript.bootstrap(source: source, owner: owner, enabled: enabled)
    }

    private func receive(_ result: AutomationResult, browser: BrowserKind, pid: Int32, installing: Bool) {
        guard isRunning(browser, pid: pid) else {
            disconnect(browser, status: L10n.text("Browser closed"))
            return
        }
        switch result {
        case .success(let response):
            guard let state = BrowserReply.state(from: response) else {
                disconnect(browser, status: L10n.text("Unable to confirm page status"), error: L10n.text("The browser returned an unrecognized connection response."))
                return
            }
            switch state {
            case .notRunning: disconnect(browser, status: L10n.text("Browser closed"))
            case .noWindow: disconnect(browser, status: L10n.text("Window closed"))
            case .open: break
            case .ready:
                update(browser, connected: true, status: L10n.text("Connected"), pid: pid)
                if installing { lastAck = (browser, Date()) }
            case .unsupported: update(browser, connected: true, status: L10n.text("This page cannot be protected"), pid: pid)
            }
        case .failure(let code, let message):
            let denied = code == -1743 || code == -1744
            disconnect(browser, status: denied ? L10n.text("Automation permission required") : L10n.text("Browser connection is not ready"), error: String(message.prefix(600)))
        }
    }

    private func isRunning(_ browser: BrowserKind, pid: Int32) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: pid) else { return false }
        return !application.isTerminated && application.bundleIdentifier == browser.bundleID
    }

    private func disconnect(_ browser: BrowserKind, status: String, error: String = "") {
        update(browser, connected: false, status: status, error: error)
    }

    private func update(_ browser: BrowserKind, connected: Bool, status: String, error: String = "", pid: Int32? = nil) {
        guard let index = connections.firstIndex(where: { $0.browser == browser }) else { return }
        connections[index].connected = connected
        connections[index].status = status
        connections[index].lastError = error
        connections[index].processIdentifier = connected ? pid : nil
        if !connected && lastAck?.browser == browser { lastAck = nil }
    }
}

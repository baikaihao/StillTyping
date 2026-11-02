import AppKit

enum AppPresentation {
    static let hideDockIconKey = "hideDockIcon"

    @discardableResult
    static func setDockIconHidden(_ hidden: Bool) -> Bool {
        let app = NSApplication.shared
        let policy: NSApplication.ActivationPolicy = hidden ? .accessory : .regular
        guard app.activationPolicy() != policy else { return true }
        let window = app.keyWindow ?? app.mainWindow
        let wasActive = app.isActive
        guard app.setActivationPolicy(policy) else { return false }
        if wasActive {
            Task { @MainActor [weak window] in
                await Task.yield()
                guard let window, window.isVisible else { return }
                window.makeKeyAndOrderFront(nil)
                app.activate()
            }
        }
        return true
    }
}

final class StillTypingAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPresentation.setDockIconHidden(UserDefaults.standard.bool(forKey: AppPresentation.hideDockIconKey))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

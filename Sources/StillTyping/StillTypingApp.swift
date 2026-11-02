import SwiftUI
import StillTypingCore

@main
struct StillTypingApp: App {
    @NSApplicationDelegateAdaptor(StillTypingAppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("StillTyping!!!", id: "main") {
            SettingsView(model: model)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.refresh()
                    model.loginItem.refresh()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1020, height: 700)

        MenuBarExtra {
            Text(model.pageStatus)
            Divider()
            Button(L10n.text("Open StillTyping!!!")) {
                openWindow(id: "main")
                Task { @MainActor in
                    await Task.yield()
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "StillTyping!!!" }) {
                        if window.isMiniaturized { window.deminiaturize(nil) }
                        window.makeKeyAndOrderFront(nil)
                    }
                    NSApplication.shared.activate()
                }
            }
            Button(model.protectionEnabled ? L10n.text("Pause Protection") : L10n.text("Enable Protection")) { model.setProtection(!model.protectionEnabled) }
            Divider()
            Button(L10n.text("Quit")) { model.shutdown(); NSApplication.shared.terminate(nil) }
        } label: {
            Image(nsImage: MenuBarLogo.image)
                .renderingMode(.template)
                .opacity(model.protectionEnabled ? 1 : 0.45)
                .accessibilityLabel("StillTyping!!!")
                .accessibilityValue(Text(model.pageStatus))
                .help(Text(verbatim: "StillTyping!!! — \(model.pageStatus)"))
        }
    }
}

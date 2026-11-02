import SwiftUI
import StillTypingCore

enum SettingsPage: String, CaseIterable, Identifiable {
    case overview, browsers, lab, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: L10n.text("Overview")
        case .browsers: L10n.text("Browsers")
        case .lab: L10n.text("Typing Test")
        case .about: L10n.text("About")
        }
    }
    var systemImage: String {
        switch self {
        case .overview: "hand.raised"
        case .browsers: "globe"
        case .lab: "keyboard"
        case .about: "gearshape"
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var selection: SettingsPage = .overview
    @State private var moreBrowsersExpanded = false

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(model: model, selection: $selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            detailView.frame(minWidth: 760, minHeight: 540)
        }
    }

    @ViewBuilder private var detailView: some View {
        switch selection {
        case .overview: overview
        case .browsers: browsers
        case .lab: lab
        case .about: about
        }
    }

    private var overview: some View {
        SettingsPageContainer {
            Text(L10n.text("Overview")).font(.largeTitle.bold())
            SettingsSection(title: L10n.text("Return protection"), systemImage: "hand.raised") {
                Toggle(L10n.text("Enable Return protection"), isOn: protectionBinding)
                Text(model.pageStatus).foregroundStyle(.secondary)
                Text(L10n.text("While composing, Return only confirms your text. Press Return again to submit."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            SettingsSection(title: L10n.text("App appearance"), systemImage: "macwindow") {
                Toggle(L10n.text("Hide Dock icon"), isOn: Binding(
                    get: { model.hideDockIcon }, set: { model.setDockIconHidden($0) }
                ))
                Text(L10n.text("Use the menu bar to reopen the window when the Dock icon is hidden."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            SettingsSection(title: L10n.text("Browser connections"), systemImage: "globe") {
                ForEach(model.connections.filter { $0.browser.isPrimary || $0.connected }) { connection in
                    browserStatus(connection)
                }
                Button(L10n.text("Set Up Browsers…")) { selection = .browsers }
            }
            SettingsSection(title: L10n.text("Try it out"), systemImage: "keyboard") {
                Text(L10n.text("Type some English using the built-in Pinyin input method to check how Return behaves."))
                    .foregroundStyle(.secondary)
                Button(L10n.text("Open Typing Test")) { selection = .lab }
            }
        }
    }

    private var browsers: some View {
        SettingsPageContainer {
            Text(L10n.text("Browsers")).font(.largeTitle.bold())
            SettingsSection(title: L10n.text("Connect browsers"), systemImage: "globe") {
                ForEach(model.connections.filter { $0.browser.isPrimary }) { connection in
                    connectionRow(connection)
                }
                DisclosureGroup(L10n.text("More"), isExpanded: $moreBrowsersExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.connections.filter { !$0.browser.isPrimary }) { connection in
                            connectionRow(connection)
                        }
                    }
                    .padding(.top, 8)
                }
                .accessibilityIdentifier("moreBrowsers")
            }
            SettingsSection(title: L10n.text("First-time setup"), systemImage: "slider.horizontal.3") {
                Text(L10n.text("Enable JavaScript from Apple Events in your browser, then click “Connect” above."))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Safari").font(.callout.weight(.medium))
                    Text(L10n.text("Settings → Developer → Allow JavaScript from Apple Events"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Chrome, Edge, Brave, Vivaldi, Opera")).font(.callout.weight(.medium))
                    Text(L10n.text("View → Developer → Allow JavaScript from Apple Events"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Arc").font(.callout.weight(.medium))
                    Text(L10n.text("Settings → Advanced → Allow JavaScript from Apple Events"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Text(L10n.text("macOS will ask for permission to control the selected browser when you first connect."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsSection(title: L10n.text("Coverage"), systemImage: "checkmark.shield") {
                Text(L10n.text("Protects the current tab. Connecting after opening, reloading, or switching pages may take about a second."))
                Text(L10n.text("Cross-origin embedded fields are not covered yet. You control the browser settings; the app does not read what you type."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var lab: some View {
        SettingsPageContainer {
            Text(L10n.text("Typing Test")).font(.largeTitle.bold())
            SettingsSection(title: L10n.text("Test Return"), systemImage: "keyboard") {
                Toggle(L10n.text("Enable protection on this test page"), isOn: $model.labProtectionEnabled)
                HStack {
                    Text(L10n.text("Submit on"))
                    Spacer()
                    Picker(L10n.text("Submit on"), selection: $model.labPhase) {
                        Text(L10n.text("Return key down")).tag("keydown")
                        Text(L10n.text("Return key up")).tag("keyup")
                    }.labelsHidden().frame(width: 200)
                }
                NativeLab(model: model).frame(height: 86)
                HStack(spacing: 20) {
                    Label(L10n.format("Submissions: %lld", Int64(model.labSubmitCount)), systemImage: "arrow.up.circle")
                        .monospacedDigit()
                    Text(model.labIsComposing ? L10n.text("Composing") : L10n.text("Not composing")).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.text("Reset Test")) { model.resetLab?() }
                }
            }
            SettingsSection(title: L10n.text("How to test"), systemImage: "info.circle") {
                Text(L10n.text("Type English using the built-in Pinyin input method. The first Return should confirm the text; the second should submit it."))
                Text(L10n.text("This page works without a browser connection and makes no network requests."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var about: some View {
        SettingsPageContainer {
            Text(L10n.text("About")).font(.largeTitle.bold())
            SettingsSection(title: "StillTyping!!!", systemImage: "character.cursor.ibeam") {
                Text(L10n.text("I’m still typing."))
                Text(L10n.format("Version %@ · Development build", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")).font(.callout).foregroundStyle(.secondary)
            }
            SettingsSection(title: L10n.text("Privacy"), systemImage: "lock.shield") {
                Text(L10n.text("Everything is processed on your Mac."))
                Text(L10n.text("Typed text, keystroke history, and clipboard contents are never stored."))
                    .foregroundStyle(.secondary)
                Text(L10n.text("Protection on webpages expires within 4 seconds after you pause or quit the app."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var protectionBinding: Binding<Bool> {
        Binding(get: { model.protectionEnabled }, set: { model.setProtection($0) })
    }

    private func browserStatus(_ connection: AppModel.Connection) -> some View {
        HStack(spacing: 10) {
            browserIcon(connection.browser)
            Text(connection.browser.name)
            Spacer()
            Text(connection.status).font(.callout).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func browserIcon(_ browser: BrowserKind) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
        } else { Image(systemName: "globe").frame(width: 24, height: 24) }
    }

    @ViewBuilder private func connectionRow(_ connection: AppModel.Connection) -> some View {
        let browser = connection.browser
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) != nil
        HStack(spacing: 12) {
            browserIcon(browser)
            VStack(alignment: .leading, spacing: 4) {
                Text(browser.name)
                Text(installed ? connection.status : L10n.text("Not installed"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(connection.connected ? L10n.text("Reconnect") : L10n.text("Connect")) { model.connect(browser) }
                .disabled(model.isBusy || !installed)
        }
        if !connection.lastError.isEmpty {
            Text(connection.lastError).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}

private struct SettingsSidebar: View {
    @Bindable var model: AppModel
    @Binding var selection: SettingsPage

    var body: some View {
        List(SettingsPage.allCases, selection: $selection) { page in
            Label(page.title, systemImage: page.systemImage).tag(page)
        }
        .navigationTitle("StillTyping!!!")
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(get: { model.protectionEnabled }, set: { model.setProtection($0) })) {
                    Label(L10n.text("Protection"), systemImage: "hand.raised")
                }
                .toggleStyle(.switch)
                Divider()
                Text("StillTyping!!!").font(.headline)
                Text(L10n.text("I’m still typing. Why submit already?")).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

struct SettingsPageContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) { content }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct SettingsSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage).font(.headline)
            VStack(alignment: .leading, spacing: 12) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.quaternary)
        }
    }
}

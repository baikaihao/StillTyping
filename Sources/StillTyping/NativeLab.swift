import SwiftUI
import WebKit

struct NativeLab: NSViewRepresentable {
    let model: AppModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "lab")
        let strings = ["language": L10n.language, "label": L10n.text("Web search field"),
                       "placeholder": L10n.text("Type hello using Pinyin, then press Return")]
        if let data = try? JSONEncoder().encode(strings), let json = String(data: data, encoding: .utf8) {
            let localization = """
            (() => {
                const strings = \(json);
                document.documentElement.lang = strings.language;
                document.querySelector('label[for="query"]').textContent = strings.label;
                document.getElementById('query').placeholder = strings.placeholder;
            })();
            """
            configuration.userContentController.addUserScript(WKUserScript(source: localization, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        if let url = AppResources.url(forResource: "guard", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            let bootstrap = source + "\n;window.StillTypingGuardFactory(window,{owner:'native-lab',enabled:\(model.labProtectionEnabled),leaseMilliseconds:0});"
            configuration.userContentController.addUserScript(WKUserScript(source: bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        model.resetLab = { [weak view] in view?.evaluateJavaScript("window.resetTest?.()") }
        if let url = AppResources.url(forResource: "lab", withExtension: "html") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        view.evaluateJavaScript("window.__stillTypingGuard_v1?.configure({enabled:\(model.labProtectionEnabled),leaseMilliseconds:0});window.testPhase='\(model.labPhase == "keyup" ? "keyup" : "keydown")';")
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.model.resetLab = nil
        coordinator.model.labIsComposing = false
        view.configuration.userContentController.removeScriptMessageHandler(forName: "lab")
        view.stopLoading()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let model: AppModel
        init(model: AppModel) { self.model = model }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let data = message.body as? [String: Any] else { return }
            if let count = data["count"] as? Int { model.labSubmitCount = count }
            if let composing = data["composing"] as? Bool { model.labIsComposing = composing }
        }
    }
}

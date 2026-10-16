import SwiftUI
import WebKit

struct ArticleWebView: NSViewRepresentable {
    let html: String?
    let zoom: Double
    let find: AppModel.FindRequest
    let onCrossReference: (URL) -> Void

    static let css: String = {
        if let url = Bundle.main.url(forResource: "oed", withExtension: "css"),
           let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        return ""
    }()

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "oedSelection")
        let script = WKUserScript(source: """
            document.addEventListener('selectionchange', function () {
              var s = window.getSelection();
              if (!s || !s.rangeCount || s.isCollapsed || !s.toString().trim()) {
                window.webkit.messageHandlers.oedSelection.postMessage({html:'', text:''});
                return;
              }
              var d = document.createElement('div');
              for (var i = 0; i < s.rangeCount; i++) d.appendChild(s.getRangeAt(i).cloneContents());
              window.webkit.messageHandlers.oedSelection.postMessage({html: d.innerHTML, text: s.toString()});
            });
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        ArticleWebViewRef.shared.webView = wv
        return wv
    }

    static func dismantleNSView(_ wv: WKWebView, coordinator: Coordinator) {
        wv.configuration.userContentController.removeScriptMessageHandler(forName: "oedSelection")
        if ArticleWebViewRef.shared.webView === wv {
            ArticleWebViewRef.shared.webView = nil
            ArticleWebViewRef.shared.clearSelection()
        }
    }

        func updateNSView(_ wv: WKWebView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if wv.pageZoom != zoom { wv.pageZoom = zoom }
        if c.loadedHTML != html {
            c.loadedHTML = html
            ArticleWebViewRef.shared.clearEntry()
            wv.loadHTMLString(Self.page(html), baseURL: nil)
        }
        if find.serial != c.lastFindSerial {
            c.lastFindSerial = find.serial
            let cfg = WKFindConfiguration()
            cfg.backwards = find.backwards
            cfg.caseSensitive = false
            cfg.wraps = true
            wv.find(find.text, configuration: cfg) { result in
                if !result.matchFound { NSSound.beep() }
            }
        }
    }

    static func page(_ body: String?) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>\(css)
        body { background: transparent; }
        </style></head><body>\(body ?? "")</body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ArticleWebView
        var loadedHTML: String?
        var lastFindSerial = 0
        init(_ p: ArticleWebView) { parent = p }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "oedSelection", let body = message.body as? [String: Any] else { return }
            ArticleWebViewRef.shared.selectionHTML = body["html"] as? String ?? ""
            ArticleWebViewRef.shared.selectionText = body["text"] as? String ?? ""
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.allow); return }
            switch url.scheme {
            case "oed-xref", "verba-xref":
                decisionHandler(.cancel)
                parent.onCrossReference(url)
            case "http", "https":
                decisionHandler(.cancel)
                if action.navigationType == .linkActivated { NSWorkspace.shared.open(url) }
            default:
                decisionHandler(.allow)
            }
        }
    }
}

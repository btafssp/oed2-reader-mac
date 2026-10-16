import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let db: OEDDatabase?
    @Published var query = ""
    @Published var hits: [Headword] = []
    @Published var selection: Headword.ID?
    @Published private(set) var current: Headword?
    @Published private(set) var html: String?
    @Published var findVisible = false
    @Published var findText = ""
    @Published var findRequest = FindRequest(text: "", backwards: false, serial: 0)
    @Published var zoom: Double = UserDefaults.standard.object(forKey: "oed.zoom") as? Double ?? 1.0 {
        didSet { UserDefaults.standard.set(zoom, forKey: "oed.zoom") }
    }
    @Published var searchFocusToken = 0

    var keyMonitor: Any?
    @Published var showAbout = false
    private var history: [Int64] = []
    private var index = -1
    private var suppressSelection = false

    struct FindRequest: Equatable { var text: String; var backwards: Bool; var serial: Int }

    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index >= 0 && index < history.count - 1 }

    init() {
        db = OEDDatabase()
        hits = db?.search("") ?? []
    }

    var statusMessage: String {
        db == nil ? "Dictionary not found at \(OEDDatabase.defaultURL.path)" : ""
    }

    func updateQuery(_ q: String) {
        query = q
        hits = db?.search(q) ?? []
        if q.trimmingCharacters(in: .whitespaces).isEmpty { showWelcome(); return }
        if let first = hits.first { select(first.id) }
    }

    func select(_ id: Int64?, push: Bool = true) {
        guard let id, let db else { return }
        if selection != id { suppressSelection = true; selection = id }
        guard current?.id != id else { return }
        current = db.headword(id: id)
        html = db.html(id: id)?.replacingOccurrences(of: "verba-xref:", with: "oed-xref:")
        if push {
            if canGoForward { history = Array(history.prefix(index + 1)) }
            if history.last != id { history.append(id) }
            index = history.count - 1
        }
    }

    func showWelcome() { suppressSelection = selection != nil; selection = nil; current = nil; html = nil }

    /// Called by the List when the user clicks a row.
    func userSelected(_ id: Int64?) {
        if suppressSelection { suppressSelection = false; if id == current?.id { return } }
        select(id)
    }

    func openCrossReference(_ url: URL) {
        guard let db, let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = Dictionary((comps.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        guard let word = items["l"] else { return }
        var pos = items["p"]; var hom = items["h"].flatMap(Int.init)
        if let p = pos, let n = Int(p) { hom = hom ?? n; pos = nil }
        guard let id = db.resolve(word: word, pos: pos, hom: hom) else { NSSound.beep(); return }
        if !hits.contains(where: { $0.id == id }), let h = db.headword(id: id) {
            query = h.lemma
            hits = db.search(h.lemma)
        }
        select(id)
    }

    func goBack() { guard canGoBack else { return }; index -= 1; select(history[index], push: false) }
    func goForward() { guard canGoForward else { return }; index += 1; select(history[index], push: false) }

    func zoomIn() { zoom = min(3.0, (zoom * 10 + 1).rounded() / 10) }
    func zoomOut() { zoom = max(0.6, (zoom * 10 - 1).rounded() / 10) }
    func zoomReset() { zoom = 1.0 }

    func useSelectionForFind() {
        let t = ArticleWebViewRef.shared.selectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { NSSound.beep(); return }
        findText = t; findVisible = true
    }
    func jumpToSelection() {
        ArticleWebViewRef.shared.webView?.evaluateJavaScript("(function(){var s=getSelection();if(!s.rangeCount||s.isCollapsed)return false;var e=s.getRangeAt(0).startContainer;if(e.nodeType!==1)e=e.parentElement;e.scrollIntoView({block:'center'});return true})()") { r, _ in
            if (r as? Bool) != true { NSSound.beep() }
        }
    }
    func focusArticle() {
        guard html != nil, let wv = ArticleWebViewRef.shared.webView else { return }
        wv.window?.makeFirstResponder(wv)
    }

    func showFind() { findVisible = true }
    func findNext() { guard !findText.isEmpty else { showFind(); return }; findRequest = .init(text: findText, backwards: false, serial: findRequest.serial + 1) }
    func findPrevious() { guard !findText.isEmpty else { showFind(); return }; findRequest = .init(text: findText, backwards: true, serial: findRequest.serial + 1) }
}

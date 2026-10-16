import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// Live selection + precomputed whole-entry share payload.
/// Selection is pushed on `selectionchange`; the whole-entry attributed string is
/// built when the article loads so the Share click can show the picker immediately
/// (NSSharingServicePicker must run inside the user-gesture turn).
@MainActor
final class ArticleWebViewRef {
    static let shared = ArticleWebViewRef()
    weak var webView: WKWebView?
    var selectionHTML: String = ""
    var selectionText: String = ""
    var hasSelection: Bool { !selectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Precomputed whole-entry share item (single NSAttributedString).
    var entryShareItem: NSAttributedString?
    var entryHeadword: String = ""

    func clearSelection() {
        selectionHTML = ""
        selectionText = ""
    }

    func prepareEntry(headword: String, html: String) {
        entryHeadword = headword
        entryShareItem = SharePayload.attributed(headword: headword, bodyHTML: html)
    }

    func clearEntry() {
        entryShareItem = nil
        entryHeadword = ""
        clearSelection()
    }
}

enum SharePayload {
    static let credit = "Oxford English Dictionary"

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func attributed(headword: String, bodyHTML: String) -> NSAttributedString? {
        let doc = """
        <!DOCTYPE html><html><head><meta charset="utf-8"></head><body>\
        \(bodyHTML)<p><br></p><p><i>— \(credit)</i></p></body></html>
        """
        guard let data = doc.data(using: .utf8),
              let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil),
              attr.length > 0 else { return nil }
        return attr
    }
}

struct ShareButton: NSViewRepresentable {
    let headword: String?
    let entryHTML: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSButton {
        let image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
            ?? NSImage(size: NSSize(width: 16, height: 16))
        let b = NSButton(image: image, target: context.coordinator, action: #selector(Coordinator.share(_:)))
        b.bezelStyle = .texturedRounded
        b.isBordered = true
        b.toolTip = "Share selection or entry"
        return b
    }

    func updateNSView(_ b: NSButton, context: Context) {
        context.coordinator.headword = headword
        context.coordinator.entryHTML = entryHTML
        b.isEnabled = headword != nil && entryHTML != nil
        // Precompute whole-entry payload off the click path.
        if let headword, let entryHTML {
            let ref = ArticleWebViewRef.shared
            if ref.entryHeadword != headword || ref.entryShareItem == nil {
                // Defer so we don't stall toolbar updates; click uses cache when ready.
                let hw = headword
                let html = entryHTML
                Task { @MainActor in
                    ref.prepareEntry(headword: hw, html: html)
                }
            }
        } else {
            ArticleWebViewRef.shared.clearEntry()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var headword: String?
        var entryHTML: String?

        @objc func share(_ sender: NSButton) {
            guard let headword else { return }
            let ref = ArticleWebViewRef.shared
            let item: NSAttributedString?
            if ref.hasSelection {
                item = SharePayload.attributed(headword: headword, bodyHTML: ref.selectionHTML)
            } else {
                item = ref.entryShareItem
                    ?? (entryHTML).flatMap { SharePayload.attributed(headword: headword, bodyHTML: $0) }
            }
            guard let item else {
                NSSound.beep()
                return
            }
            NSSharingServicePicker(items: [item]).show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}

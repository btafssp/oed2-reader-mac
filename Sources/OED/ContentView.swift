import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @FocusState private var findFocused: Bool
    @FocusState private var listFocused: Bool

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                TextField("Search the OED", text: Binding(get: { model.query }, set: { model.updateQuery($0) }))
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .onSubmit { model.focusArticle() }
                    .padding(8)
                List(model.hits, selection: Binding(get: { model.selection }, set: { model.userSelected($0) })) { h in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(h.label).lineLimit(1)
                        if let f = h.viaForm {
                            Text("form: \(f)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(h.id)
                }
                .listStyle(.sidebar)
                .focused($listFocused)
                .onKeyPress(.return) { model.focusArticle(); return .handled }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            VStack(spacing: 0) {
                if model.findVisible { findBar; Divider() }
                if model.html != nil {
                    ArticleWebView(html: model.html, zoom: model.zoom, find: model.findRequest,
                                   onCrossReference: { model.openCrossReference($0) })
                } else if model.db != nil {
                    ArticleWebView(html: Welcome.html, zoom: model.zoom, find: model.findRequest,
                                   onCrossReference: { _ in })
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("Oxford English Dictionary").font(.headline)
                        Text(model.statusMessage.isEmpty ? "Type a word to look it up." : model.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(model.current?.label ?? "OED")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!model.canGoBack).help("Back")
                    Button { model.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!model.canGoForward).help("Forward")
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button { model.showAbout = true } label: { Label("About OED", systemImage: "info.circle") }
                        .help("About OED")
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareButton(headword: model.html == nil ? nil : model.current?.label, entryHTML: model.html)
                        .help("Share")
                }
            }
        }
        .sheet(isPresented: $model.showAbout) { AboutView() }
        .onAppear { searchFocused = true; installKeyMonitor() }
        .onDisappear { if let m = model.keyMonitor { NSEvent.removeMonitor(m) }; model.keyMonitor = nil }
        .onChange(of: model.searchFocusToken) { _, _ in focusSearchSelectingAll() }
        .onChange(of: model.findVisible) { _, v in if v { findFocused = true } }
    }

    private func focusSearchSelectingAll() {
        searchFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
        }
    }

    /// ⇧Tab steps back: article → headword list → search field (text selected), as in VerbaMac.
    private func installKeyMonitor() {
        guard model.keyMonitor == nil else { return }
        model.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Unlisted alternates: ⌘L = Search for a New Word, ⌘+ (⇧⌘=) = Make Text Bigger.
            if event.window?.isKeyWindow == true, flags.contains(.command), !flags.contains(.option), !flags.contains(.control) {
                let ch = event.charactersIgnoringModifiers ?? ""
                if ch == "l", flags == .command { model.searchFocusToken += 1; return nil }
                if ch == "+" || (ch == "=" && flags == [.command, .shift]) { model.zoomIn(); return nil }
            }
            guard event.keyCode == 48, flags == .shift, event.window?.isKeyWindow == true else { return event }
            if let wv = ArticleWebViewRef.shared.webView, let fr = event.window?.firstResponder as? NSView, fr.isDescendant(of: wv) {
                listFocused = true; return nil
            }
            if listFocused { focusSearchSelectingAll(); return nil }
            return event
        }
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            TextField("Find in entry", text: $model.findText)
                .textFieldStyle(.roundedBorder)
                .focused($findFocused)
                .frame(maxWidth: 260)
                .onSubmit { model.findNext() }
            Button("Previous") { model.findPrevious() }.disabled(model.findText.isEmpty)
            Button("Next") { model.findNext() }.disabled(model.findText.isEmpty)
            Spacer()
            Button { model.findVisible = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 10).padding(.vertical, 6).background(.bar)
    }
}

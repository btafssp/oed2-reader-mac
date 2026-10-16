import SwiftUI
import AppKit

@main
struct OEDApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.openWindow) private var openWindow

    init() { CommandLineCheck.runIfRequested() }

    var body: some Scene {
        WindowGroup("OED") {
            ContentView().environmentObject(model).frame(minWidth: 760, minHeight: 480)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OED") { model.showAbout = true }
            }
            CommandGroup(replacing: .newItem) {
                Button("Search for a New Word…") { model.searchFocusToken += 1 }.keyboardShortcut("f", modifiers: [.command, .option])
            }
            CommandGroup(after: .textEditing) {
                Menu("Find") {
                    Button("Find…") { model.showFind() }.keyboardShortcut("f", modifiers: .command)
                    Button("Find Next") { model.findNext() }.keyboardShortcut("g", modifiers: .command)
                    Button("Find Previous") { model.findPrevious() }.keyboardShortcut("g", modifiers: [.command, .shift])
                    Divider()
                    Button("Use Selection for Find") { model.useSelectionForFind() }.keyboardShortcut("e", modifiers: .command)
                    Button("Jump to Selection") { model.jumpToSelection() }.keyboardShortcut("j", modifiers: .command)
                }
            }
            CommandGroup(replacing: .help) {
                Button("Symbols and Abbreviations") { openWindow(id: "help") }
                    .keyboardShortcut("?", modifiers: .command)
                Divider()
                Button("OED Symbols and Conventions (oed.com)") {
                    NSWorkspace.shared.open(URL(string: "https://www.oed.com/information/understanding-entries/symbols-and-other-conventions")!)
                }
            }
            CommandMenu("Go") {
                Button("Back") { model.goBack() }.keyboardShortcut("[", modifiers: .command).disabled(!model.canGoBack)
                Button("Forward") { model.goForward() }.keyboardShortcut("]", modifiers: .command).disabled(!model.canGoForward)
            }
            CommandGroup(after: .sidebar) {
                Button("Make Text Bigger") { model.zoomIn() }.keyboardShortcut("=", modifiers: .command)
                Button("Make Text Smaller") { model.zoomOut() }.keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { model.zoomReset() }.keyboardShortcut("0", modifiers: .command)
            }
        }
        Window("Symbols and Abbreviations", id: "help") { HelpView() }
            .defaultSize(width: 720, height: 820)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OED").font(.title.weight(.semibold))
                    Text("A reader for your own OED2 CD-ROM data.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(Self.versionString).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            Text("Credits").font(.headline)
            credit("Dictionary content", "© Oxford University Press; not included.")
            credit("Zstandard (zstd)", "Decompression library by Meta Platforms, Inc. and affiliates. BSD License.")
            Text("Not affiliated with or endorsed by Oxford University Press.").font(.caption).foregroundStyle(.secondary)
            Text("Built with the help of Grok Bot").font(.caption).foregroundStyle(.secondary)
            Link("OED symbols and conventions (oed.com)",
                 destination: URL(string: "https://www.oed.com/information/understanding-entries/symbols-and-other-conventions")!)
                .font(.caption)
            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// "Version 0.9.0 (1)", read from the bundle.
    static var versionString: String {
        let info = Bundle.main.infoDictionary
        return "Version \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    private func credit(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// `OED --check [word]`: open the DB, decode one entry, print a summary, exit.
enum CommandLineCheck {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--check") else { return }
        let word = args.count > i + 1 ? args[i + 1] : "love"
        guard let db = OEDDatabase() else { print("FAIL: cannot open \(OEDDatabase.defaultURL.path)"); exit(1) }
        let hits = db.search(word)
        guard let first = hits.first, let html = db.html(id: first.id) else { print("FAIL: no decodable entry for \(word)"); exit(2) }
        print("OK db=\(OEDDatabase.defaultURL.path) entries=\(db.count()) dict=\(db.zdict?.count ?? 0)B")
        print("query=\(word) hits=\(hits.count) first=\(first.label) id=\(first.id) html=\(html.count) chars")
        print(String(html.prefix(160)))
        if let x = db.resolve(word: "see", pos: "v", hom: nil) { print("xref see:v -> id \(x) \(db.headword(id: x)?.label ?? "")") }
        exit(html.hasPrefix("<article") ? 0 : 3)
    }
}

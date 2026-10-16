import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct Headword: Identifiable, Hashable, Sendable {
    let id: Int64
    let lemma: String
    let lemmaNorm: String
    let pos: String
    let hom: Int?
    let flag: String
    /// Set when matched through the variants table (the form typed).
    var viaForm: String? = nil

    var label: String {
        var s = flag.isEmpty ? "" : flag
        s += lemma
        if !pos.isEmpty { s += ", " + pos }
        if let hom { s += Self.superscript(hom) }
        return s
    }
    static func superscript(_ n: Int) -> String {
        let map: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

/// Read-only access to the private oed.sqlite (VerbaMac scheme + pos/hom/flag + variants).
final class OEDDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private(set) var zdict: Data?
    private let lock = NSLock()
    private var statements: [String: OpaquePointer] = [:]

    static var defaultURL: URL {
        if let env = ProcessInfo.processInfo.environment["OED_DB"], !env.isEmpty { return URL(fileURLWithPath: env) }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("OED/oed.sqlite")
    }

    init?(url: URL = OEDDatabase.defaultURL) {
        var h: OpaquePointer?
        guard sqlite3_open_v2(url.path, &h, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let h else {
            if let h { sqlite3_close(h) }; return nil
        }
        db = h
        _ = query("SELECT dict FROM zdicts WHERE lang = 'eng'") { st in
            if sqlite3_step(st) == SQLITE_ROW, let b = sqlite3_column_blob(st, 0) {
                self.zdict = Data(bytes: b, count: Int(sqlite3_column_bytes(st, 0)))
            }
        }
        if count() == 0 { return nil }
    }

    deinit {
        for s in statements.values { sqlite3_finalize(s) }
        if let db { sqlite3_close(db) }
    }

    private func query<T>(_ sql: String, _ bind: [Any] = [], _ body: (OpaquePointer) -> T) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let db else { return nil }
        var st = statements[sql]
        if st == nil {
            guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK, st != nil else { return nil }
            statements[sql] = st
        }
        let s = st!
        defer { sqlite3_reset(s); sqlite3_clear_bindings(s) }
        for (i, v) in bind.enumerated() {
            let idx = Int32(i + 1)
            switch v {
            case let x as String: _ = x.withCString { sqlite3_bind_text(s, idx, $0, -1, SQLITE_TRANSIENT) }
            case let x as Int: sqlite3_bind_int64(s, idx, Int64(x))
            case let x as Int64: sqlite3_bind_int64(s, idx, x)
            default: break
            }
        }
        return body(s)
    }

    private static func text(_ s: OpaquePointer, _ c: Int32) -> String {
        sqlite3_column_text(s, c).map { String(cString: $0) } ?? ""
    }

    private static func headword(_ s: OpaquePointer) -> Headword {
        Headword(id: sqlite3_column_int64(s, 0), lemma: text(s, 1), lemmaNorm: text(s, 2), pos: text(s, 3),
                 hom: sqlite3_column_type(s, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(s, 4)), flag: text(s, 5))
    }

    private static let cols = "a.id, a.lemma, a.lemma_norm, COALESCE(a.pos,''), a.hom, COALESCE(a.flag,'')"

    func count() -> Int {
        query("SELECT COUNT(*) FROM articles") { sqlite3_step($0) == SQLITE_ROW ? Int(sqlite3_column_int64($0, 0)) : 0 } ?? 0
    }

    /// Prefix match on headwords, plus every entry that lists the typed text as a variant form.
    func search(_ raw: String, limit: Int = 200) -> [Headword] {
        let key = Self.normalize(raw)
        var out: [Headword] = []
        var seen = Set<Int64>()
        if key.isEmpty {
            _ = query("SELECT \(Self.cols) FROM articles a ORDER BY a.lemma_norm, a.id LIMIT ?", [limit]) { s in
                while sqlite3_step(s) == SQLITE_ROW { out.append(Self.headword(s)) }
            }
            return out
        }
        _ = query("SELECT \(Self.cols) FROM articles a WHERE a.lang='eng' AND a.lemma_norm >= ? AND a.lemma_norm < ? ORDER BY a.lemma_norm, a.id LIMIT ?",
                  [key, key + "\u{10FFFF}", limit]) { s in
            while sqlite3_step(s) == SQLITE_ROW { let h = Self.headword(s); if seen.insert(h.id).inserted { out.append(h) } }
        }
        _ = query("SELECT \(Self.cols), v.form FROM variants v JOIN articles a ON a.id = v.article_id WHERE v.form_norm = ? ORDER BY a.id LIMIT 100", [key]) { s in
            while sqlite3_step(s) == SQLITE_ROW {
                var h = Self.headword(s); h.viaForm = Self.text(s, 6)
                if seen.insert(h.id).inserted { out.append(h) }
            }
        }
        // Exact headword matches first, then variant hits, then the rest of the prefix list.
        let exact = out.filter { $0.lemmaNorm == key && $0.viaForm == nil }
        let vars = out.filter { $0.viaForm != nil }
        let rest = out.filter { $0.lemmaNorm != key && $0.viaForm == nil }
        return exact + vars + rest
    }

    func headword(id: Int64) -> Headword? {
        query("SELECT \(Self.cols) FROM articles a WHERE a.id = ?", [id]) { s in
            sqlite3_step(s) == SQLITE_ROW ? Self.headword(s) : nil
        } ?? nil
    }

    /// Decompressed article HTML.
    func html(id: Int64) -> String? {
        let blob: Data? = query("SELECT html_zstd FROM articles WHERE id = ?", [id]) { s in
            guard sqlite3_step(s) == SQLITE_ROW, let b = sqlite3_column_blob(s, 0) else { return nil }
            return Data(bytes: b, count: Int(sqlite3_column_bytes(s, 0)))
        } ?? nil
        guard let blob, let data = ZstdCodec.decompress(blob, dictionary: zdict) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Resolve a cross-reference (word, part of speech, homograph) to an article id.
    func resolve(word: String, pos: String?, hom: Int?) -> Int64? {
        let key = Self.normalize(word)
        var rows: [Headword] = []
        _ = query("SELECT \(Self.cols) FROM articles a WHERE a.lemma_norm = ? ORDER BY a.id", [key]) { s in
            while sqlite3_step(s) == SQLITE_ROW { rows.append(Self.headword(s)) }
        }
        if rows.isEmpty {
            _ = query("SELECT \(Self.cols) FROM variants v JOIN articles a ON a.id = v.article_id WHERE v.form_norm = ? ORDER BY a.id", [key]) { s in
                while sqlite3_step(s) == SQLITE_ROW { rows.append(Self.headword(s)) }
            }
        }
        guard !rows.isEmpty else { return nil }
        var pool = rows
        if let pos, !pos.isEmpty {
            let p = pos.lowercased()
            let byPos = rows.filter { $0.pos.lowercased().hasPrefix(p + ".") || $0.pos.lowercased() == p }
            if !byPos.isEmpty { pool = byPos }
        }
        if let hom, let h = pool.first(where: { $0.hom == hom }) { return h.id }
        return pool.first?.id
    }

    private static let fold: [Character: String] = ["æ": "ae", "œ": "oe", "þ": "th", "ð": "th", "ȝ": "y", "ſ": "s",
                                                    "ß": "ss", "ƿ": "w", "ᵹ": "g", "ø": "o", "ł": "l", "đ": "d", "ı": "i"]

    /// Same key as the Python converter: lowercase, fold old letters, strip accents, keep [a-z0-9].
    static func normalize(_ s: String) -> String {
        var t = ""
        for ch in s.lowercased() { if let f = fold[ch] { t += f } else { t.append(ch) } }
        t = t.applyingTransform(.stripDiacritics, reverse: false) ?? t
        return String(t.unicodeScalars.filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) }.map(Character.init))
    }
}

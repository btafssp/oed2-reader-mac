#!/usr/bin/env python3
"""OED2 CD-ROM HTML -> oed.sqlite converter (VerbaMac-compatible articles + zdicts scheme).
Use only with data you own; the resulting database must not be redistributed."""
import argparse, html, json, re, sqlite3, sys, unicodedata
from collections import Counter
from multiprocessing import Pool
from pathlib import Path
from urllib.parse import quote
import zstandard as zstd
import entities, xcodes

LANG = 'eng'
DICT_SIZE = 112 * 1024
LEVEL = 3

TAGMAP = {  # oed tag -> (html tag, class)
    'hg': ('header', 'hg'), 'hw': ('span', 'hw'), 'tf': ('span', 'label'), 'pg': ('div', 'pron'),
    'ph': ('span', 'ph'), 'spg': ('div', 'forms'), 'dg': ('div', 'etym'), 'def': ('div', 'def'),
    'qp': ('div', 'quots'), 'pqp': ('div', 'quots'), 'q': ('div', 'q'), 'd': ('span', 'date'),
    'c': ('span', 'auth'), 'w': ('cite', 'work'), 'qt': ('span', 'qt'), 'gk': ('span', 'gk'),
    'add': ('section', 'add'), 'r': ('span', 'rom'), 'nobr': ('span', 'nobr'), 'cs': ('span', 'cs'),
    'co': ('span', 'co'), 'cu': ('span', 'cu'), 'ov': ('span', 'ov'), 'bco': ('span', 'co'),
    'bcu': ('span', 'cu'), 'bo': ('span', 'co'), 'bu': ('span', 'cu'), 'bsco': ('span', 'co'),
    'bscu': ('span', 'cu'), 'dn': ('span', 'dn'), 'nu': ('span', 'nu'), 'insc': ('span', 'insc'),
    'scs': ('span', 'scs'), 'susc': ('span', 'susc'), 'pic': ('span', 'pic'), 'l': ('span', 'l'),
}
KEEP = {'b', 'i', 'sup', 'sub', 'table', 'tr', 'td'}

TOKEN = re.compile(r'<(/?)([A-Za-z][A-Za-z0-9]*)([^>]*)>|&([A-Za-z0-9#]+);|xxff([03])')
E_BLOCK = re.compile(r'<e>.*?</e>', re.S)


class Stats:
    def __init__(self):
        self.ent = Counter(); self.xc = Counter(); self.tags = Counter()


def xref(href):
    # x:word:pos n   (pos and homograph optional)
    parts = href[2:].split(':')
    word = html.unescape(parts[0])
    q = 'l=' + quote(word, safe='')
    if len(parts) > 1 and parts[1]:
        pos = parts[1].split(' ')
        q += '&p=' + quote(pos[0], safe='')
        if len(pos) > 1 and pos[1].isdigit():
            q += '&h=' + pos[1]
    return f'verba-xref:{LANG}?{q}'


def convert(raw, st):
    s = E_BLOCK.sub('', raw)
    out = []
    sc = []  # small-caps stack: True = opened span
    pos = 0
    for m in TOKEN.finditer(s):
        out.append(s[pos:m.start()]); pos = m.end()
        close, tag, attrs, ent, xx = m.groups()
        if ent is not None or xx is not None:
            name = ent if ent is not None else 'ff' + xx
            if name == 'ff3':
                out.append('<span class="sc">'); sc.append(True); continue
            if name == 'ff2':
                sc.append(False); continue
            if name == 'ff0':
                if sc and sc.pop(): out.append('</span>')
                continue
            t, status = entities.resolve(name)
            st.ent[(name, status)] += 1
            if t is None:
                out.append(f'<span class="unk" title="&amp;{name};">⟨?⟩</span>')
            else:
                out.append(t)
            continue
        tl = tag.lower()
        if tl in ('v', 'f', 'e', 'qp', 'pqp'):
            continue
        if re.fullmatch(r'x[0-9A-F]{4}', tag):
            t, status = xcodes.resolve(tag); st.xc[(tag, status)] += 1
            out.append(t if t is not None else f'<span class="unk" title="{tag}">⟨?⟩</span>')
            continue
        if tl == 'nlb':
            out.append('<br class="nlb">'); continue
        if tl == 'br':
            out.append('<br>'); continue
        if tl == 'hr':
            out.append('<hr class="sep">'); continue
        if tl == 'a':
            if close:
                out.append('</a>'); continue
            h = re.search(r'href="([^"]*)"', attrs); n = re.search(r'name="([^"]*)"', attrs)
            if h and h.group(1).startswith('x:'):
                out.append(f'<a class="xref" href="{html.escape(xref(h.group(1)))}">')
            elif h:
                out.append(f'<a href="{h.group(1)}">')
            elif n:
                out.append(f'<a class="sn" id="s-{n.group(1)}">')
            else:
                out.append('<a>')
            continue
        if tl == 'font':
            if close: out.append('</span>'); continue
            cls = 'small' if 'size' in attrs else ('symfont' if 'face' in attrs else 'font')
            out.append(f'<span class="{cls}">'); continue
        if tl in KEEP:
            out.append(f'<{close}{tl}>'); continue
        if tl in TAGMAP:
            h, cls = TAGMAP[tl]
            if close:
                out.append(f'</{h}>')
            else:
                extra = ' lang="grc"' if tl == 'gk' else ''
                out.append(f'<{h} class="{cls}"{extra}>')
            continue
        st.tags[tl] += 1  # unknown tag: drop, keep content
    out.append(s[pos:])
    while sc:
        if sc.pop(): out.append('</span>')
    body = ''.join(out)
    return unicodedata.normalize('NFC', body)


def strip_tags(h):
    return html.unescape(re.sub(r'<[^>]+>', '', h))


FOLD = str.maketrans({'æ': 'ae', 'œ': 'oe', 'þ': 'th', 'ð': 'th', 'ȝ': 'y', 'ſ': 's', 'ß': 'ss',
                      'ƿ': 'w', 'ᵹ': 'g', 'ø': 'o', 'ł': 'l', 'đ': 'd', 'ı': 'i'})


def norm(s):
    s = s.lower().translate(FOLD)
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]', '', s)


SUPD = str.maketrans('0123456789', '⁰¹²³⁴⁵⁶⁷⁸⁹')


def parse_head(body):
    m = re.search(r'<header class="hg">(.*?)</header>', body, re.S)
    hwm = re.search(r'<span class="hw">(.*?)</span>(?=[^<]*(?:<span class="label"|</header>|$))', m.group(1) if m else '', re.S)
    hw = hwm.group(1) if hwm else (m.group(1) if m else '')
    hom = None
    sm = re.search(r'<sup>([^<]*?)(\d+)</sup>\s*$', hw.strip())
    if sm: hom = int(sm.group(2))
    text = strip_tags(re.sub(r'<sup>.*?</sup>', '', hw)).strip()
    flag = ''
    if text[:1] in '†‖¶': flag, text = text[0], text[1:].strip()
    if ',' in text:
        lemma, pos = text.split(',', 1); pos = pos.strip()
    else:
        lemma, pos = text, ''
    lemma = lemma.strip().replace('ˈ', '').replace('ˌ', '').replace('·', '')
    lemma = re.sub(r'\s+', ' ', lemma)
    return lemma, pos, hom, flag


def variants(body, lemma_n):
    out = []
    for f in re.findall(r'<div class="forms">(.*?)</div>', body, re.S):
        for b in re.findall(r'<b>(.*?)</b>', f, re.S):
            t = strip_tags(b).strip(' ,.;:')
            if not t or t.startswith('-') or t.endswith('-') or len(t) > 40: continue
            t = t.replace('(', '').replace(')', '')
            n = norm(t)
            if n and n != lemma_n: out.append((t, n))
    seen = set(); res = []
    for t, n in out:
        if n not in seen: seen.add(n); res.append((t, n))
    return res


def build(raw):
    st = Stats()
    body = convert(raw, st)
    lemma, pos, hom, flag = parse_head(body)
    ln = norm(lemma)
    art = (f'<article class="entry oed" data-lang="{LANG}">' + body + '</article>')
    return dict(lemma=lemma, norm=ln, pos=pos, hom=hom, flag=flag, html=art,
                vars=variants(body, ln), ent=st.ent, xc=st.xc, tags=st.tags)


def read_lines(SRC):
    for f in sorted(SRC.glob('*.htm'), key=lambda p: int(p.stem)):
        with open(f, 'rb') as fh:
            for line in fh:
                line = line.rstrip(b'\r\n')
                if line.startswith(b'<hg>'):
                    yield line.decode('cp1252', errors='replace')


SCHEMA = """
PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF; PRAGMA page_size = 8192; PRAGMA encoding = 'UTF-8';
CREATE TABLE articles (
  id INTEGER PRIMARY KEY, lemma TEXT NOT NULL, lemma_norm TEXT NOT NULL,
  lang TEXT NOT NULL CHECK (lang IN ('lat','grc','eng')), html_zstd BLOB NOT NULL, plain TEXT,
  pos TEXT, hom INTEGER, flag TEXT);
CREATE INDEX idx_norm ON articles(lang, lemma_norm);
CREATE TABLE variants (form TEXT NOT NULL, form_norm TEXT NOT NULL, article_id INTEGER NOT NULL REFERENCES articles(id));
CREATE INDEX idx_var ON variants(form_norm);
CREATE VIRTUAL TABLE articles_fts USING fts5(lemma, plain, content='articles');
CREATE TABLE zdicts (lang TEXT PRIMARY KEY, dict BLOB NOT NULL);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--src', required=True, type=Path, help='folder with the CD-ROM HTML files (1.htm ... 10.htm)')
    ap.add_argument('--out', default='oed.sqlite')
    ap.add_argument('--report', default='build_report.json')
    ap.add_argument('--limit', type=int, default=0); a = ap.parse_args()
    lines = list(read_lines(a.src))
    if a.limit: lines = lines[:a.limit]
    print('entries', len(lines), file=sys.stderr)
    with Pool() as pool:
        step = max(1, len(lines) // 6000)
        samples = [r['html'].encode() for r in pool.map(build, lines[::step], chunksize=64)]
        d = zstd.train_dictionary(DICT_SIZE, samples, level=LEVEL).as_bytes()
        cctx = zstd.ZstdCompressor(level=LEVEL, dict_data=zstd.ZstdCompressionDict(d))
        out = Path(a.out); out.unlink(missing_ok=True)
        con = sqlite3.connect(out); con.executescript(SCHEMA)
        con.execute('INSERT INTO zdicts VALUES (?,?)', (LANG, d))
        ent = Counter(); xc = Counter(); tags = Counter(); nvar = 0
        for i, r in enumerate(pool.imap(build, lines, chunksize=256), 1):
            con.execute('INSERT INTO articles(id,lemma,lemma_norm,lang,html_zstd,plain,pos,hom,flag) VALUES (?,?,?,?,?,NULL,?,?,?)',
                        (i, r['lemma'], r['norm'], LANG, cctx.compress(r['html'].encode()), r['pos'], r['hom'], r['flag']))
            con.executemany('INSERT INTO variants VALUES (?,?,?)', [(t, n, i) for t, n in r['vars']])
            nvar += len(r['vars']); ent.update(r['ent']); xc.update(r['xc']); tags.update(r['tags'])
            if i % 50000 == 0: print(i, file=sys.stderr)
    con.execute("INSERT INTO articles_fts(rowid, lemma, plain) SELECT id, lemma, '' FROM articles")
    con.execute("INSERT INTO meta VALUES ('source','OED2 HTML (user-supplied)'),('private','true')")
    con.commit(); con.execute('VACUUM'); con.close()
    rep = {'entries': len(lines), 'variants': nvar, 'bytes': out.stat().st_size,
           'entities_flagged': {f'{k[0]}': v for k, v in ent.items() if k[1] != 'ok'},
           'xcodes_flagged': {f'{k[0]} ({k[1]})': v for k, v in xc.items() if k[1] != 'ok'},
           'unknown_tags': dict(tags)}
    Path(a.report).write_text(json.dumps(rep, ensure_ascii=False, indent=1))
    print(json.dumps({k: rep[k] for k in ('entries', 'variants', 'bytes')}))


if __name__ == '__main__':
    main()

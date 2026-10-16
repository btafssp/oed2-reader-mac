# oed2-reader-mac

An unofficial, native macOS (SwiftUI) reader for the HTML data on the **Oxford English Dictionary, Second Edition, CD-ROM**. It is meant for people who own that CD-ROM and may already have converted it for GoldenDict (for example to a SLOB file) and would like a fast, fully native Mac app instead.

**No dictionary data is included, and none will be accepted.** You must supply HTML from your own copy of the CD-ROM. The database you build is for your personal use; please do not redistribute it.

Not affiliated with or endorsed by Oxford University Press. "Oxford English Dictionary" and "OED" are trademarks of Oxford University Press. The app's "Symbols and Abbreviations" help page reproduces OUP's own explanatory text, © Oxford University Press.

## Features

- Instant headword search with prefix matching, plus lookup by variant spellings
- Clickable cross-references, back/forward history
- Faithful rendering of the CD-ROM's special glyph codes as Unicode
- Find in entry (⌘F, ⌘G, ⇧⌘G, ⌘E, ⌘J), text size (⌘=, ⌘−, ⌘0)
- Keyboard shortcuts follow Apple's Dictionary app wherever it has a matching command (⌥⌘F to search a new word; ⌘L also works)
- Share button (copies the entry or selection, with a credit line)
- Welcome page with conventions and shortcuts; Help ▸ Symbols and Abbreviations (⌘?)

## Requirements

- macOS 14 or later, Apple silicon
- Xcode command-line tools (Swift 5.9+)
- To build from source: `brew install zstd`. The released app bundles its own copy of libzstd (BSD licence, see `ThirdParty/zstd/LICENSE`).
- To convert data: Python 3 and `pip install zstandard`
- The OED2 CD-ROM HTML files (`1.htm` … `10.htm`)

## 1. Convert your data

```sh
cd converter
python3 -m venv .venv && . .venv/bin/activate && pip install zstandard
python3 convert_oed.py --src /path/to/OED_HTM --out oed.sqlite
```

This produces `oed.sqlite` (about 290 MB) and `build_report.json`, which lists any glyph codes or entities that were flagged.

## 2. Install the database

```sh
mkdir -p ~/Library/Application\ Support/OED
mv oed.sqlite ~/Library/Application\ Support/OED/
```

## 3. Build and install the app

```sh
./build_app.sh --install      # builds and copies OED.app to /Applications
```

By default the app is signed ad hoc. To sign with your own certificate or change the bundle identifier:

```sh
SIGN_IDENTITY="Apple Development: you@example.com (XXXXXXXXXX)" BUNDLE_ID=com.example.OED ./build_app.sh --install
```

## Glyph-code confidence

The CD-ROM uses private codes (`<xNNNN>`) and named entities for special characters. `converter/xcodes.py` and `converter/entities.py` split their mappings into `OK` (confident) and `UNSURE` (best guesses that need review). A few glyphs have no Unicode equivalent and are shown as a bracketed description, e.g. `[short mordent]`.

Corrections are very welcome. Please open an issue citing **only the code** (e.g. `x7170`) and the proposed Unicode character. Do not paste dictionary text into issues.

## Credits

Built on code from [VerbaMac](https://github.com/btafssp/VerbaMac), a Latin and Greek morphology and lexicon app. Built with the help of Grok Bot. Decompression by [Zstandard](https://github.com/facebook/zstd).

## Licence

GNU General Public License v3.0; see `LICENSE`. Dictionary content is © Oxford University Press and is not covered by this licence.

enum Welcome {
    static let html = """
    <style>
    .welcome { max-width: 40em; margin: 1.2em auto; }
    .welcome h1 { color: var(--hw); font-size: 1.9em; margin: 0 0 .1em; }
    .welcome .sub { color: var(--muted); font-style: italic; margin: 0 0 1.2em; }
    .welcome h2 { color: var(--sense); font-size: 1.05em; margin: 1.3em 0 .35em; border-bottom: 1px solid var(--rule); padding-bottom: .15em; }
    .welcome p { margin: .3em 0; }
    .welcome table { border-collapse: collapse; margin: .2em 0; }
    .welcome td { padding: .18em .9em .18em 0; vertical-align: top; }
    .welcome kbd { font: 12px -apple-system, "Helvetica Neue", sans-serif; background: var(--etym-bg); border: 1px solid var(--rule); border-radius: 4px; padding: 1px 6px; white-space: nowrap; }
    .welcome .tip { background: var(--etym-bg); border-left: 3px solid var(--rule); padding: .4em .7em; margin-top: 1.4em; font-size: .93em; }
    </style>
    <div class="welcome">
    <h1>Welcome to the OED</h1>
    <p class="sub">The Oxford English Dictionary, Second Edition, on your Mac.</p>
    <h2>Looking up a word</h2>
    <p>Start typing in the search box. The list shows every headword beginning with what you have typed, and the first match opens straight away. Older or variant spellings work too: a match found through a variant form shows that form beneath the headword.</p>
    <h2>Moving around</h2>
    <table>
    <tr><td><kbd>Return</kbd></td><td>From the search box or headword list into the entry, so the arrow keys scroll it</td></tr>
    <tr><td><kbd>Tab</kbd></td><td>Move from the search box to the headword list</td></tr>
    <tr><td><kbd>↑</kbd> <kbd>↓</kbd></td><td>Step through the headword list</td></tr>
    <tr><td><kbd>⇧Tab</kbd></td><td>Step back: entry → headword list → search box (with the text selected)</td></tr>
    <tr><td><kbd>⌥⌘F</kbd></td><td>Search for a new word (<kbd>⌘L</kbd> works too)</td></tr>
    <tr><td><kbd>⌘[</kbd> <kbd>⌘]</kbd></td><td>Back and forward through the entries you have viewed (also the arrows in the toolbar)</td></tr>
    </table>
    <p>Words shown in <a class="xref">blue with a dotted underline</a> are cross-references; click one to jump to that entry.</p>
    <h2>Reading an entry</h2>
    <table>
    <tr><td><kbd>⌘F</kbd></td><td>Find text within the entry</td></tr>
    <tr><td><kbd>⌘G</kbd> <kbd>⇧⌘G</kbd></td><td>Next and previous match</td></tr>
    <tr><td><kbd>⌘E</kbd> <kbd>⌘J</kbd></td><td>Use the selection for Find; jump to the selection</td></tr>
    <tr><td><kbd>⌘=</kbd> <kbd>⌘−</kbd> <kbd>⌘0</kbd></td><td>Larger, smaller, and actual text size</td></tr>
    </table>
    <p class="tip">Where Apple’s Dictionary app has a matching command, the keyboard shortcut here is the same.</p>
    <h2>Sharing</h2>
    <p>The Share button in the toolbar sends whatever text you have selected; with nothing selected it sends the whole entry. Either way a credit line is added at the end.</p>
    <h2>Symbols and abbreviations</h2>
    <p>Choose <b>Help › Symbols and Abbreviations</b> or press <kbd>⌘?</kbd> for a key to the signs and short forms used in the entries.</p>
    <p class="tip">This page appears each time the OED opens. Just start typing to look up a word.</p>
    </div>
    """
}

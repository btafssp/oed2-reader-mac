"""OED2 custom entity -> Unicode. resolve(name) -> (text, status); status in ok|unsure|unknown."""
import unicodedata

COMB = {  # suffix -> combining char
    'acu': '\u0301', 'grave': '\u0300', 'gra': '\u0300', 'circ': '\u0302', 'uml': '\u0308', 'mac': '\u0304',
    'breve': '\u0306', 'tilde': '\u0303', 'ced': '\u0327', 'hacek': '\u030C', 'dotab': '\u0307',
    'dotbl': '\u0323', 'undl': '\u0331', 'ang': '\u030A', 'hook': '\u0328', 'asper': '\u0314',
    'lenis': '\u0313', 'frown': '\u0342', 'isub': '\u0345', 'circbl': '\u032D', 'frbl': '\u032E',
    'umlbl': '\u0324', 'brbl': '\u032E',
}
GREEK_MARKS = {'asper', 'lenis', 'frown', 'isub'}
LAT2GRK = {'a': 'α', 'e': 'ε', 'h': 'η', 'i': 'ι', 'o': 'ο', 'u': 'υ', 'w': 'ω', 'r': 'ρ',
           'A': 'Α', 'E': 'Ε', 'H': 'Η', 'I': 'Ι', 'O': 'Ο', 'U': 'Υ', 'W': 'Ω', 'R': 'Ρ'}
BASES = {
    'ae': 'æ', 'Ae': 'Æ', 'oe': 'œ', 'Oe': 'Œ', 'th': 'þ', 'Th': 'Þ', 'edh': 'ð', 'Edh': 'Ð',
    'ygh': 'ȝ', 'Ygh': 'Ȝ', 'ope': 'ɛ', 'revope': 'ɜ', 'revv': 'ʌ', 'revc': 'ɔ', 'fata': 'ɑ',
    'rfa': 'ɒ', 'schwa': 'ə', 'shti': 'ɪ', 'shtu': 'ʊ', 'sh': 'ʃ', 'zh': 'ʒ', 'ng': 'ŋ',
    'vdftheta': 'θ', 'eszett': 'ß', 'wyn': 'ƿ', 'Wyn': 'Ƿ', 'glots': 'ʔ', 'rglots': 'ʕ',
    'dlessi': 'ı', 'longs': 'ſ', 'asg': 'ᵹ', 'udh': 'ɥ', 'uda': 'ɐ', 'udA': 'ⱯⱯ'[0], 'udw': 'ʍ',
    'revr': 'ɹ', 'lsyllab': 'l̩', 'nsyllab': 'n̩', 'msyllab': 'm̩', 'rsyllab': 'r̩',
    'sm': 'ˈ', 'smm': 'ˌ', 'lm': 'ː', 'p': '′', 'ayin': 'ʿ', 'hgz': 'ȥ', 'bantuo': 'ɔ', 'Bantuo': 'Ɔ',
    'thinqm': '?', 'pall': 'ʎ', 'paln': 'ɲ', 'shtibar': 'ɨ', 'shtubar': 'ʉ', 'vvf': 'ɣ',
}
BARS = {'b': 'ƀ', 'd': 'đ', 'h': 'ħ', 'l': 'ł', 'L': 'Ł', 'o': 'ø', 'O': 'Ø', 'i': 'ɨ', 'u': 'ʉ',
        'p': 'ꝑ', 'th': 'ꝥ', 'Th': 'Ꝥ', 'g': 'ǥ'}
GREEK = dict(alpha='α', beta='β', gamma='γ', delta='δ', epsilon='ε', zeta='ζ', eta='η', theta='θ',
             iota='ι', kappa='κ', lambda_='λ', mu='μ', nu='ν', xi='ξ', omicron='ο', pi='π', rho='ρ',
             sigma='σ', fsigma='ς', tau='τ', upsilon='υ', phi='φ', chi='χ', psi='ψ', omega='ω',
             digamma='ϝ', oldbeta='ϐ', phi2='ϕ')
GREEK['lambda'] = GREEK.pop('lambda_')
for k, v in list(GREEK.items()):
    if k not in ('fsigma', 'digamma', 'oldbeta', 'phi2'):
        GREEK[k[0].upper() + k[1:]] = v.upper()
EXPLICIT = {
    '#038': '&amp;', '#062': '&gt;', 'lt': '&lt;', 'gt': '&gt;', 'nbsp': '\u00a0', 'times': '×',
    'from': '<', 'psense': '¶', 'hbar': 'ħ', 'circplus': '⊕', 'real': 'ℜ', 'ffilig': 'ﬃ',
    'ffllig': 'ﬄ', 'fllig': 'ﬂ', 'stlig': 'ﬆ', 'ctlig': 'ct', 'istlig': 'ist', 'ifflig': 'iff',
    'ifilig': 'ifi', 'frakE': '𝔈', 'frakL': '𝔏', 'cyrO': 'О', 'cyrP': 'П', 'cyra': 'а',
    'cyrd': 'д', 'cyre': 'е', 'cyrhard': 'ъ', 'cyrjat': 'ѣ', 'cyrm': 'м', 'cyrn': 'н', 'cyrr': 'р',
    'cyrsoft': 'ь', 'cyrt': 'т', 'cyry': 'ы', 'hebtav': 'ת', 'segol': '\u05B6', 'qamets': '\u05B8',
    'sheva': '\u05B0', 'hireq': '\u05B4', 'shadda': '\u0651', 'vavpath': 'וַ', 'vavsheva': 'וְ',
    'devdh': 'ध', 'devph': 'फ', 'devt': 'त', 'devth': 'थ', 'devrt': 'ट', 'devrth': 'ठ',
    'devrfls': 'ष', 'runash': 'ᚫ', 'runwyn': 'ᚹ', 'egsampi': 'ͳ', 'Abarab': 'Ā', 'ctilde': 'c̃',
    'aisub': 'ᾳ', 'wisub': 'ῳ', 'hisub': 'ῃ', 'click': 'ǀ', 'reva': 'ɒ', 'revC': 'Ɔ',
    'rvow': 'ʴ', 'wapos': 'ʼ', 'glagjat': 'Ⱑ', 'glagjeri': 'Ⱐ', 'glagjeru': 'Ⱏ', 'egy3': 'ꜣ',
    'egyasper': 'ꜥ', 'woqab': 'ʋ', 'smYpr': 'ˈ', 'smRpr': 'ˈ', 'dlessj1': 'ȷ', 'dlessj2': 'ȷ',
    'dlessj3': 'ȷ', 'cdsb': 'c', 'odsb': 'o', 'cbigb': '(', 'obigb': ')', 'cbigpren': '(',
    'obigpren': ')', 'cbigsb': '[', 'obigsb': ']', 'revsc': '⸵', 'par': '¶', 'udqm': '¿', 'Asg': 'Ᵹ', 'Tbarab': 'T̄', 'clenis': 'c̓', 'epsiloncirc': 'ε̂', 'etaisub': 'ῃ', 'mfrown': 'm͂', 'ohgcirc': 'ô', 'roasper': 'ῥ', 'ruasper': 'ῥ', 'shtsyllmac': 'ɪ̩̄', 'lm': 'ː',
}
# 2026-10-15 second look (OED symbol help: oupjapan help-symbols)
ENT_FIX = {'smYpr':'ʏ','smRpr':'ʀ','revsc':'⹎','obigpren':'(','cbigpren':')','obigb':'{','cbigb':'}',
  'obigsb':'[','cbigsb':']','odsb':'⟦','cdsb':'⟧','udA':'∀','ifflig':'ﬀ','ifilig':'ﬁ','istlig':'ﬅ',
  'Bantuo':'Ʊ','bantuo':'ʊ','rvow':'˔','ohgcirc':'ˆ','shtsyllmac':'⏓'}
EXPLICIT.update(ENT_FIX)
UNSURE = {  # mapped but needs human review
    'asg': 'insular g ᵹ (OE glosses)', 'from': '“<” (derived from)', 'par': '¶ (seems to be a line/para break in quotations)',
    'revsc': 'reversed semicolon ⸵ (ME punctus)', 'smYpr': 'stress mark? rendered ˈ', 'smRpr': 'stress mark? rendered ˈ',
    'udA': 'turned A Ɐ', 'rvow': 'rhotic hook ʴ', 'woqab': 'ʋ (Ewe)', 'egsampi': 'Greek sampi ͳ',
    'cdsb': 'c with ? (dsb)', 'odsb': 'o with ? (dsb)', 'cbigb': 'big bracket (math)', 'obigb': 'big bracket (math)',
    'cbigpren': 'big paren (math)', 'obigpren': 'big paren (math)', 'cbigsb': 'big square bracket', 'obigsb': 'big square bracket',
    'click': 'click letter ǀ', 'hgz': 'z with hook ȥ (OHG)', 'vvf': 'ɣ voiced velar fricative', 'pall': 'ʎ',
    'paln': 'ɲ', 'Bantuo': 'Ɔ', 'bantuo': 'ɔ', 'p': 'prime ′', 'ctlig': 'ct ligature (plain)',
    'istlig': 'ist ligature (plain)', 'ifflig': 'iff (plain)', 'ifilig': 'ifi (plain)', 'devrfls': 'Devanagari ष?',
    'efrbl': 'e + breve below', 'ifrbl': 'i + breve below', 'ufrbl': 'u + breve below', 'schwafrbl': 'ə + breve below',
    'lumlbl': 'l + diaeresis below', 'aacuced': 'a acute cedilla', 'Hbrbl': 'H + breve below',
    'wasperfrown': 'Greek', 'Elenisfrown': 'Greek', 'thinqm': 'thin question mark → ?',
    'nfgra': 'stand-alone `', 'reva': 'reversed a → ɒ', 'Wasperfrown': 'Greek', 'dlessj1': 'ȷ variant', 'dlessj2': 'ȷ variant', 'dlessj3': 'ȷ variant',
    'Tbarab': 'T with bar above T̄', 'clenis': 'c̓ (c + comma above)', 'ohgcirc': 'OHG ô?', 'roasper': 'ρ with asper? (ῥ)', 'ruasper': 'ρ/υ with asper? (ῥ)', 'shtsyllmac': 'ɪ̩̄ (syllabic ɪ + macron)?', 'mfrown': 'm͂',
}
for _k in ENT_FIX.keys() | {'par','from','p','devrfls','asg','hgz','thinqm'}: UNSURE.pop(_k, None)
NF = {'acu': '´', 'gra': '`', 'grave': '`', 'circ': 'ˆ', 'mac': 'ˉ', 'uml': '¨', 'tilde': '˜',
      'hacek': 'ˇ', 'breve': '˘', 'asper': '῾', 'frown': '͂', 'ced': '¸'}
SUFFIXES = sorted(COMB, key=len, reverse=True)


def _parse(name):
    """Split into base + list of suffixes; return None if not decomposable."""
    marks = []
    s = name
    while True:
        for suf in SUFFIXES + ['bar']:
            if s.endswith(suf) and len(s) > len(suf):
                marks.insert(0, suf)
                s = s[: -len(suf)]
                break
        else:
            return s, marks


def resolve(name):
    if name in ('ff0', 'ff2', 'ff3'):
        return None, 'ok'
    if name in EXPLICIT:
        return EXPLICIT[name], ('unsure' if name in UNSURE else 'ok')
    n = name
    for tail in ('pr', 'sc'):
        if n.endswith(tail) and len(n) > len(tail) + 0 and n not in BASES and n not in GREEK:
            n2 = n[: -len(tail)]
            if n2 in BASES or n2 in GREEK or n2 in EXPLICIT or _parse(n2)[0] in BASES or len(_parse(n2)[0]) == 1 or _parse(n2)[0].startswith('g'):
                n = n2
                break
    if n in EXPLICIT:
        return EXPLICIT[n], ('unsure' if n in UNSURE or name in UNSURE else 'ok')
    if n in BASES:
        return BASES[n], ('unsure' if n in UNSURE or name in UNSURE else 'ok')
    if n in GREEK:
        return GREEK[n], 'ok'
    if n.startswith('nf') and n[2:] in NF:
        return NF[n[2:]], 'ok'
    base, marks = _parse(n)
    greek = False
    if base.startswith('g') and len(base) == 2:
        base, greek = base[1], True
    if any(m in GREEK_MARKS for m in marks):
        greek = True
    if 'bar' in marks:
        if base in BARS and marks == ['bar']:
            return BARS[base], 'ok'
        if base in BARS:
            marks = [m for m in marks if m != 'bar']
            ch = BARS[base]
        else:
            return None, 'unknown'
    elif base in BASES:
        ch = BASES[base]
    elif len(base) == 1 and base.isalpha():
        ch = LAT2GRK.get(base, None) if greek else base
        if ch is None:
            return None, 'unknown'
    else:
        return None, 'unknown'
    if not marks:
        return None, 'unknown'
    out = unicodedata.normalize('NFC', ch + ''.join(COMB[m] for m in marks))
    st = 'unsure' if (name in UNSURE or n in UNSURE or any(m in ('frbl', 'umlbl', 'brbl') for m in marks)) else 'ok'
    return out, st

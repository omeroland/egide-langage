#!/usr/bin/env python3
"""ADR-0018 mechanical checks (scratch tool, not part of the build; needs `menhir` on PATH).

  python3 -I docs/adr/attachments/0018-check.py          # from the repository root

1. Conflict counts: `menhir --explain` on the four Menhir transcriptions (D = ADR-0013 attachment, B, A, C) and on the
   variants that undo one design choice each (a conflict count > 0 is the argument for that choice).
2. Parse check: the programs of 0018-syntax-options.md (a feature tour and examples/tenants_api.egd, each written in D,
   A, B and C) are tokenised with the proposed lexer rules and fed to `menhir --interpret` on the matching grammar.
   Negative controls must be rejected.
The tokenizer is a 100-line model of the lexer, enough for these programs; it is evidence for the grammar, not a lexer."""
import os, re, subprocess, sys, tempfile

ATT = os.path.dirname(os.path.abspath(__file__))
GRAMMARS = {'d': '0013-menhir-check.mly', 'b': '0018-menhir-braces.mly', 'a': '0018-menhir-go.mly',
            'c': '0018-menhir-reason.mly'}
tmp = tempfile.mkdtemp(prefix='adr0018-')

def conflicts(text, name):
    path = os.path.join(tmp, name + '.mly')
    open(path, 'w').write(text)
    subprocess.run(['menhir', '--explain', path], capture_output=True, text=True)
    cf = os.path.join(tmp, name + '.conflicts')
    return sum(1 for l in open(cf) if l.startswith('** Conflict')) if os.path.exists(cf) else 0

def load(k): return open(os.path.join(ATT, GRAMMARS[k])).read()

def variant(base, old, new):
    t = load(base)
    assert old in t, (base, old)
    return t.replace(old, new)

# ------------------------------------------------------------------ 1. conflict counts
rows = [('D  status quo (indentation, ADR-0013..0017)', conflicts(load('d'), 'd')),
        ('B  braces, Go-style line termination', conflicts(load('b'), 'b')),
        ('A  Go skin (`func`, `name Type`), lambda heads `(x: T) => e`', conflicts(load('a'), 'a')),
        ('C  Reason-shaped after four concessions', conflicts(load('c'), 'c'))]
rows += [('B  + open-ended ranges allowed everywhere (`for i in 0.. {`)',
          conflicts(variant('b', "range: bitor {} | bitor DOTDOT bitor {} | bitor DOTDOTEQ bitor {}\n  | DOTDOT bitor {} | DOTDOTEQ bitor {}",
                            "range: bitor {} | bitor DOTDOT {} | bitor DOTDOT bitor {} | bitor DOTDOTEQ bitor {}\n  | DOTDOT {} | DOTDOT bitor {} | DOTDOTEQ bitor {}"), 'b_range')),
         ('A  + lambda heads `(x T) => e`',
          conflicts(variant('a', "lambda_param: option(mode2) IDENT option(preceded(COLON, ty)) {}", "lambda_param: option(mode2) IDENT option(ty) {}")
                    .replace("cover_item: expr option(preceded(COLON, ty)) {} | open_range {}", "cover_item: expr option(ty) {} | open_range {}")
                    .replace("| mode2 expr option(preceded(COLON, ty)) {}", "| mode2 expr option(ty) {}"), 'a1')),
         ('C  + bitwise `|` restored', conflicts(variant('c', "bitor: bitxor {}\n", "bitor: bitxor {} | bitor PIPE bitxor {}\n"), 'c_bitor')),
         ('C  + set literals and `{}` restored',
          conflicts(variant('c', "  | LBRACE map_entries RBRACE {} | LBRACE map_entry comp_clauses RBRACE {}",
                            "  | LBRACE RBRACE {} | LBRACE map_entries RBRACE {} | LBRACE expr_list RBRACE {}\n  | LBRACE map_entry comp_clauses RBRACE {} | LBRACE expr comp_clauses RBRACE {}"), 'c_set')),
         ('C  + unparenthesised guard `when g =>`',
          conflicts(variant('c', "option(preceded(WHEN, delimited(LPAREN, expr, RPAREN)))", "option(preceded(WHEN, expr))"), 'c_guard'))]
print('Menhir conflict states (`menhir --explain`, count of "** Conflict" in the .conflicts file)')
for name, n in rows: print(f'  {n:3d}  {name}')

# ------------------------------------------------------------------ 2. programs and tokenizer
annex = open(os.path.join(ATT, '0018-syntax-options.md'), encoding='utf-8').read()
progs = dict(re.findall(r'```text name=(\w+)\n(.*?)\n```', annex, re.S))

KW = {k: k.upper() for k in """module import fn struct enum trait impl type let var comptime pub return break continue defer
 yield if elif else match case for in while loop with given unsafe not and or self dyn new where as true false inout take
 using""".split()}
KW['Self'] = 'SELFT'
def keywords(mode):
    k = dict(KW)
    if mode == 'a': del k['fn']; k['func'] = 'FN'; del k['match']; k['switch'] = 'MATCH'; del k['elif']
    if mode == 'b': del k['elif']
    if mode == 'c': del k['match']; k['switch'] = 'SWITCH'; k['when'] = 'WHEN'; del k['case']; del k['elif']
    return k
PUNCT = [('<<=', 'SHLEQ'), ('>>=', 'SHREQ'), ('..=', 'DOTDOTEQ'), ('**', 'STARSTAR'), ('==', 'EQEQ'), ('!=', 'NEQ'),
 ('<=', 'LE'), ('>=', 'GE'), ('+=', 'PLUSEQ'), ('-=', 'MINUSEQ'), ('*=', 'STAREQ'), ('/=', 'SLASHEQ'), ('%=', 'PERCENTEQ'),
 ('&=', 'AMPEQ'), ('|=', 'PIPEEQ'), ('^=', 'CARETEQ'), ('->', 'ARROW'), ('=>', 'FATARROW'), ('|>', 'PIPEGT'),
 ('<<', 'SHL'), ('>>', 'SHR'), ('..', 'DOTDOT'), ('+', 'PLUS'), ('-', 'MINUS'), ('*', 'STAR'), ('/', 'SLASH'),
 ('%', 'PERCENT'), ('=', 'EQ'), ('<', 'LT'), ('>', 'GT'), ('&', 'AMP'), ('|', 'PIPE'), ('^', 'CARET'), ('~', 'TILDE'),
 ('?', 'QUESTION'), ('.', 'DOT'), (',', 'COMMA'), (':', 'COLON'), (';', 'SEMI'), ('@', 'AT'), ('(', 'LPAREN'),
 (')', 'RPAREN'), ('[', 'LBRACKET'), (']', 'RBRACKET'), ('{', 'LBRACE'), ('}', 'RBRACE')]
DUR = r'(?:ns|us|ms|s|min|h)'

def lex_line(line, kw):
    toks, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c == ' ': i += 1; continue
        if c == '#': break
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', line[i:])
        if m:
            w = m.group(0); j = i + len(w)
            if j < n and line[j] == '"' and w not in kw and w not in ('r', 'b'):          # prefixed template
                k, depth = j + 1, 0
                while k < n:
                    if line[k] == '\\': k += 2; continue
                    if line[k] == '{':
                        if line[k:k+2] == '{{': k += 2; continue
                        depth += 1
                    elif line[k] == '}':
                        if line[k:k+2] == '}}' and depth == 0: k += 2; continue
                        depth -= 1
                    elif line[k] == '"' and depth == 0: break
                    elif line[k] == '"':
                        k += 1
                        while line[k] != '"': k += 1
                    k += 1
                toks.append('TEMPLATE'); i = k + 1; continue
            if w == 'go' and toks and toks[-1] == 'IMPORT': toks.append('GO')
            elif w in kw: toks.append(kw[w])
            else: toks.append('IDENT')
            i = j; continue
        m = re.match(r'\d[\d_]*\.' + DUR + r'(?![A-Za-z0-9_])', line[i:])
        if m: toks.append('DURATION'); i += len(m.group(0)); continue
        m = re.match(r'\d[\d_]*\.\d[\d_]*(?:e[+-]?\d+)?|\d[\d_]*e[+-]?\d+', line[i:])
        if m: toks.append('FLOAT'); i += len(m.group(0)); continue
        m = re.match(r'0x[0-9A-Fa-f_]+|\d[\d_]*', line[i:])
        if m: toks.append('INT'); i += len(m.group(0)); continue
        if c == '"':
            k = i + 1
            while line[k] != '"': k += 2 if line[k] == '\\' else 1
            toks.append('STRING'); i = k + 1; continue
        for p, name in PUNCT:
            if line.startswith(p, i): toks.append(name); i += len(p); break
        else: raise SystemExit(f'cannot lex {line[i:i+12]!r}')
    return toks

END = {'IDENT', 'INT', 'FLOAT', 'DURATION', 'STRING', 'TEMPLATE', 'TRUE', 'FALSE', 'SELF', 'SELFT', 'RETURN', 'BREAK',
       'CONTINUE', 'RPAREN', 'RBRACKET', 'RBRACE', 'QUESTION'}
CONT = {'DOT', 'PIPEGT', 'AND', 'OR', 'RPAREN', 'RBRACKET', 'RBRACE'}   # next line starts with one of these: no NEWLINE

def tokens(mode, src):
    kw = keywords(mode)
    lines = []
    for raw in src.split('\n'):
        t = lex_line(raw, kw)
        if t: lines.append((len(raw) - len(raw.lstrip(' ')), t))
    out = []
    if mode in ('a', 'b'):            # proposed rule: NEWLINE after a line whose last token can end a statement
        for idx, (w, t) in enumerate(lines):
            out += t
            nxt = lines[idx+1][1][0] if idx + 1 < len(lines) else None
            if t[-1] in END and nxt not in CONT: out.append('NEWLINE')
    elif mode == 'c':
        for w, t in lines: out += t
    else:                             # D: LEX-030..LEX-036 (indentation)
        stack, depth, logical = [0], 0, []
        for w, t in lines:
            if depth == 0 and logical and w > logical[-1][0] and t[0] in ('DOT', 'PIPEGT', 'AND', 'OR') and logical[-1][1][-1] != 'COLON':
                logical[-1][1].extend(t)
            elif depth > 0 and logical: logical[-1][1].extend(t)
            else: logical.append([w, list(t)])
            for tk in t:
                depth += 1 if tk in ('LPAREN', 'LBRACKET', 'LBRACE') else -1 if tk in ('RPAREN', 'RBRACKET', 'RBRACE') else 0
        for idx, (w, t) in enumerate(logical):
            top = stack[-1]
            if idx == 0: pass
            elif w == top: out.append('NEWLINE')
            elif w > top: stack.append(w); out.append('INDENT')
            else:
                out.append('NEWLINE')
                while stack[-1] > w: stack.pop(); out.append('DEDENT')
            out += t
        out.append('NEWLINE')
        while len(stack) > 1: stack.pop(); out.append('DEDENT')
    return out + ['EOF']

def accepts(mode, src):
    sent = ' '.join(tokens(mode, src)) + '\n'
    r = subprocess.run(['menhir', '--interpret', os.path.join(ATT, GRAMMARS[mode])], input=sent, capture_output=True, text=True)
    return 'ACCEPT' in r.stdout

print('\nParse check of the annex programs (`menhir --interpret` on the matching grammar)')
ok = True
for name in sorted(progs):
    mode = name[0]
    res = accepts(mode, progs[name])
    ok &= res
    print(f'  {"ACCEPT" if res else "REJECT"}  {name}')
neg = {  # negative controls for B: each must be rejected
    'else on the next line': ('b', progs['b_tour'].replace('    } else if cents < 1000 {', '    }\n    else if cents < 1000 {')),
    'opening brace on the next line': ('b', progs['b_tour'].replace('fn area(s: Shape) -> float {', 'fn area(s: Shape) -> float\n{')),
    'block-ended expression as operand (SYN-015)': ('b', 'module x\n\nfn f() {\n    let n = 1 + match c {\n        case A: 1\n    }\n}\n'),
    'open-ended range before a block': ('b', 'module x\n\nfn f() {\n    for i in 0.. {\n        g(i)\n    }\n}\n'),
    'statements on one line without separator': ('b', 'module x\n\nfn f() { g() h() }\n')}
pos = {  # positive controls for B: each must be accepted
    'call closed on its own line, no trailing comma': ('b', 'module x\n\nfn f() {\n    g(a,\n      b\n    )\n}\n'),
    'multi-line map literal, no trailing comma': ('b', 'module x\n\nfn f() {\n    let m = {"a": 1,\n        "b": 2\n    }\n    m\n}\n'),
    'one-line if/else and one-line function': ('b', 'module x\n\nfn f(c: bool) -> int { if c { return 1 } else { return 2 } }\n'),
    'set literal in a header: if x == {1} { ... }': ('b', 'module x\n\nfn f() {\n    if x == {1} {\n        g()\n    }\n}\n')}
print('\nPositive controls (must be ACCEPT)')
for name, (mode, src) in pos.items():
    res = accepts(mode, src); ok &= res
    print(f'  {"ACCEPT" if res else "REJECT (unexpected)"}  {name}')
print('\nNegative controls (must be REJECT)')
for name, (mode, src) in neg.items():
    res = accepts(mode, src); ok &= not res
    print(f'  {"REJECT" if not res else "ACCEPT (unexpected)"}  {name}')
sys.exit(0 if ok else 1)

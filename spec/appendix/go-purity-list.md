# Appendix A. Go purity list

This appendix defines the **format and review process** of the official classification of Go standard-library
functions (GO-041). The data lives in [`go-purity/`](go-purity/), one file per Go minor version (`go1.25.lst`).

## A.1 Classes

| Class | Meaning | Égide requirement at call site |
|-------|---------|--------------------------------|
| `pure` | no I/O, no global mutable state, deterministic | none |
| `clock` | reads time or waits | `Clock` |
| `rand` | reads OS entropy or a global random source | `Rand` |
| `stdout` / `stderr` / `stdin` | standard streams | `Stdout` / `Stderr` / `Stdin` |
| `fs` | file system | `Dir` (the Égide wrapper passes the root) |
| `env` | environment, argv, user database | `Env` |
| `proc` | processes, signals | `Proc` |
| `net` | network | `Net` |
| `log` | global logger | `Log` |
| `go` | anything else, or unknown | `Go` |
| `forbidden` | never callable (`unsafe`, `plugin`, `syscall` raw calls…) | — (compile-time error) |

## A.2 File format

```
# go1.25.lst — Égide Go purity list
# <import path>[.<Receiver>].<Func> <class> [# note]
# A line "<import path>.* <class>" sets the default for every exported function of the package.
strings.* pure
fmt.* pure
fmt.Print stdout
fmt.Printf stdout
fmt.Println stdout
fmt.Scan stdin
time.* pure
time.Now clock
time.LoadLocation fs   # reads the zoneinfo database
os.* go
```

- **[GOP-001]** Lines are sorted by import path, then function. Duplicate keys are an error.
- **[GOP-002]** A function not matched by any line (neither exact nor `.*`) is classified `go`.
- **[GOP-003]** Every change to a list file requires review by the `security-reviewer` role and the owner.
- **[GOP-004]** A new Go minor version starts as a copy of the previous list, then the call-graph analysis (GO-042) is
  run over the standard library and every function whose computed class differs from the list is reviewed by hand.

## A.3 Initial classification (Go 1.25, summary)

| Packages | Class |
|----------|-------|
| `strings`, `bytes`, `strconv`, `unicode`, `unicode/utf8`, `unicode/utf16`, `slices`, `maps`, `sort`, `cmp`, `iter`, `errors`, `unique` | `pure` |
| `math`, `math/big`, `math/bits`, `math/cmplx`, `container/list`, `container/heap`, `container/ring` | `pure` |
| `encoding/json`, `encoding/xml`, `encoding/csv`, `encoding/base64`, `encoding/base32`, `encoding/hex`, `encoding/binary`, `encoding/pem`, `encoding/asn1` | `pure` |
| `regexp`, `text/template`, `html/template`, `html`, `text/tabwriter`, `mime`, `net/url`, `net/netip`, `path` | `pure` |
| `bufio`, `io`, `compress/*`, `archive/tar`, `archive/zip` | `pure` (authority lives in the `Reader`/`Writer` passed in) |
| `hash/*`, `crypto/sha256`, `crypto/sha512`, `crypto/sha3`, `crypto/hmac`, `crypto/aes`, `crypto/cipher`, `crypto/hkdf`, `crypto/subtle` | `pure` |
| `crypto/md5`, `crypto/sha1`, `crypto/des`, `crypto/rc4` | `pure`, plus a deprecation warning |
| `sync`, `sync/atomic` | `pure` (see GO-032 for sharing) |
| `fmt` | mixed: `Sprint*`, `Errorf`, `Fprint*`, `Sscan*` `pure`; `Print*` `stdout`; `Scan*` `stdin` |
| `path/filepath` | mixed: `Join`, `Clean`, `Base`, `Dir`, `Ext`, `Rel`, `Split`, `Match` `pure`; `Walk`, `WalkDir`, `Glob`, `Abs`, `EvalSymlinks` `fs` |
| `time` | mixed: `Duration`, `Parse*`, `Date`, `Unix`, formatting `pure`; `Now`, `Since`, `Until`, `Sleep`, `After`, `Tick`, `NewTimer`, `NewTicker` `clock`; `LoadLocation` `fs` |
| `crypto/ed25519`, `crypto/ecdsa`, `crypto/rsa` | mixed: sign/verify `pure`; `GenerateKey` `rand` |
| `crypto/tls` | mixed: config types `pure`; `Dial`, `Listen` `net` |
| `math/rand`, `math/rand/v2` | mixed: `New(src)` and methods on explicit sources `pure`; top-level functions `rand` |
| `log`, `log/slog` | mixed: `slog.New(handler)` `pure`; default-logger functions `log` |
| `crypto/rand` | `rand` |
| `os`, `io/ioutil`, `os/user` | `go` by default; common functions refined to `fs` / `env` |
| `os/signal`, `os/exec` | `proc` |
| `net`, `net/http`, `net/smtp`, `net/rpc`, `database/sql` | `net` |
| `context` | `pure`; contexts are injected by the runtime (GO-022) |
| `syscall`, `unsafe`, `plugin`, `runtime/cgo`, `net/http/pprof`, `expvar` | `forbidden` |
| `reflect` | `pure`, except `NewAt` and `Value.UnsafePointer` `forbidden` |

The authoritative data is `go-purity/go1.25.lst`; task T-0040 generates and reviews the complete file.

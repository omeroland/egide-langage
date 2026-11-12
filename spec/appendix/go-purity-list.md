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
| `regexp`, `html`, `text/tabwriter`, `net/url`, `net/netip`, `path` | `pure` |
| `text/template`, `html/template` | mixed: `pure`, except `ParseFiles` and `ParseGlob` (package functions and `(*Template)` methods) `fs`, and `(*Template).Execute` and `ExecuteTemplate` `go` (they run functions registered with `Funcs`; `Funcs` itself stays `pure` because its argument falls under GO-042 item 4) |
| `mime` | mixed: `pure`, except `TypeByExtension` and `ExtensionsByType` `fs` (they read the system mime tables) and `AddExtensionType` `go` (global state) |
| `bufio`, `io`, `compress/*`, `archive/tar` | `pure` (authority lives in the `Reader`/`Writer` passed in) |
| `archive/zip` | mixed: `pure`, except `OpenReader` `fs` |
| `context`, `time` (clock readers) | `context.WithDeadline`, `WithDeadlineCause`, `WithTimeout`, `WithTimeoutCause`, `time.AfterFunc`, `time.Unix`, `UnixMilli`, `UnixMicro` (they return a `Time` in the `Local` zone, read from `$TZ` and `/etc/localtime`), `time.Parse`, `ParseInLocation` and `(*Time).UnmarshalJSON`, `UnmarshalText`, `UnmarshalBinary`, `GobDecode` (a zone abbreviation or an offset that equals the local one selects `Local`), and `(Time).Local` are `clock`; the rest of the package keeps its class. The `Local` zone never reaches Égide data (GO-025) |
| `hash/*`, `crypto/sha256`, `crypto/sha512`, `crypto/sha3`, `crypto/hmac`, `crypto/aes`, `crypto/cipher`, `crypto/hkdf`, `crypto/subtle` | `pure` |
| `crypto/md5`, `crypto/sha1`, `crypto/des`, `crypto/rc4` | `pure`, plus a deprecation warning |
| `sync`, `sync/atomic` | `pure` (see GO-032 for sharing) |
| `fmt` | mixed: `Sprint*`, `Errorf`, `Fprint*`, `Sscan*` `pure`; `Print*` `stdout`; `Scan*` `stdin` |
| `path/filepath` | mixed: `Join`, `Clean`, `Base`, `Dir`, `Ext`, `Rel`, `Split`, `Match` `pure`; `Walk`, `WalkDir`, `Glob`, `Abs`, `EvalSymlinks` `fs` |
| `time` | mixed: `Duration`, `Date` with an explicit location, formatting `pure`; `Now`, `Since`, `Until`, `Sleep`, `After`, `Tick`, `NewTimer`, `NewTicker` `clock`; `LoadLocation` `fs` |
| `crypto/ed25519`, `crypto/ecdsa`, `crypto/rsa` | mixed: sign/verify `pure`; `GenerateKey` `rand` |
| `crypto/tls` | `go` by default (`Client`, `Server` and `Handshake` read `rand.Reader`, the clock and the system roots); `Dial`, `DialWithDialer`, `Listen` `net`; `LoadX509KeyPair` `fs`; `X509KeyPair` `pure` |
| `math/rand`, `math/rand/v2` | mixed: `New(src)` and methods on explicit sources `pure`; top-level functions `rand` |
| `log`, `log/slog` | mixed: `slog.New(handler)` `pure`; default-logger functions `log` |
| `crypto/rand` | `rand` |
| `os`, `io/ioutil`, `os/user` | `go` by default; common functions refined to `fs` / `env` |
| `os/signal`, `os/exec` | `proc` |
| `net`, `net/http`, `net/smtp`, `net/rpc`, `database/sql` | `net` |
| `context` | `pure`; contexts are injected by the runtime (GO-022) |
| `syscall`, `unsafe`, `plugin`, `runtime/cgo`, `net/http/pprof`, `expvar` | `forbidden` |
| `flag` | `go` by default; `Parse` `env` (reads `os.Args`) |
| `reflect` | `pure`, except `NewAt` and `Value.UnsafePointer` `forbidden`, and `Value.Call`, `Value.CallSlice`, `Value.Seq`, `Value.Seq2` (they call function-kinded values), `Value.Method`, `Value.MethodByName` and `Value.Interface` `go` (they invoke code chosen at run time, for example `reflect.ValueOf(os.Stdout).MethodByName("Write").Call(...)` writes to standard output) |

The authoritative data is `go-purity/go1.25.lst`; task T-0040 generates and reviews the complete file.

- **[GOP-007]** Exported package-level **variables** of the standard library are classified by lines
  `<import path>.var.<Name> <class> [immutable]` (for example `io.var.EOF pure immutable`, `os.var.Args go`).
  `<import path>.*` does not cover variables, and a variable with no line is `go`. By GO-042 item 3 the class of a
  variable of pointer, slice, map, function, channel or interface type, or of a struct or array that contains one, is `go`
  whatever its line says, unless the line carries `immutable`; the annotation requires a note naming why no exported
  operation can change what the value reaches (GOP-003 review). Value-typed variables (numbers, strings, booleans and
  arrays and structs of them) take their line's class. A read of such a variable in the
  user-package closure takes that class (GO-042 item 3).
- **[GOP-008]** A package-level `pure` default (`<import path>.* pure`) is a claim that no function of the package reads
  ambient state: the clock, the environment, argv, a random source, the disk, the user or the network database. The
  review of GOP-003 checks it function by function and does not accept a wholesale `pure` for a package whose
  functions can reach such state (this audit is T-0040's; the seed list is known to contain wholesale lines that fail
  it, corrected in this appendix for `text/template`, `html/template`, `archive/zip`, `crypto/tls`, `mime`, `reflect`
  and the clock readers of `context` and `time`).

## A.4 Initialisation lines (GO-045)

- **[GOP-005]** For every standard package the list holds a line `<import path>.init <class>` giving the class of the
  package's initialisers and of those of the standard packages it imports. `<import path>.*` does not cover `init`.
  Only `pure` makes the package importable (E0705 otherwise). A `forbidden` package of A.3 has the init class `forbidden`
  unless a line says otherwise (`syscall`, `unsafe` and the runtime-bound packages of A.5 are the expected exceptions).
  The lines are reviewed under GOP-003, and the review decides explicitly, for each of them, packages whose
  initialisation reads the environment or registers state (`net/http`, `crypto/*`, `database/sql`, `os`).

## A.5 Runtime-bound packages

- **[GOP-006]** The packages linked by the Égide runtime (`runtime/go/rt`) are exempt from the init rules of GO-045 because
  every program of the Go backend links them anyway (on the native backend only programs with Go interop do, and the
  exemption then only skips a check on packages that are linked anyway): the standard packages imported by `runtime/go/rt` (today `context`, `errors`,
  `fmt`, `io`, `os`, `sync`, `time`) and their transitive standard imports, listed in the file `go1.25.runtime-bound`
  next to the list. The file is generated from the runtime's import graph and versioned with the list. A CI check fails if
  the committed file differs from the one generated from `runtime/go/rt`, so that a change of the runtime's imports cannot
  widen the exemption unreviewed; every change of the file is reviewed under GOP-003. A package that is not in it is never
  exempt.

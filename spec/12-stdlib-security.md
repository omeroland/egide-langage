# 12. Security types of the standard library

These protections are ordinary `std` types. They are sound because capabilities are unforgeable (CAP-002), sink types
can be built only by the `std` templates (CT-040, CT-041), and there is no reflection or global state to bypass them.

## 12.1 Untrusted data

- **[SEC-001]** Every value entering the process from outside — request bodies, headers, query and path parameters,
  `argv`, environment variables, stdin, socket reads, and file contents read through `Dir.read_untrusted` — is typed
  `Untrusted[T]`.
- **[SEC-002]** `Untrusted[T]` exposes no operation that returns `T` except:
  validation into a validated type or through a parser (`Port.parse(u)`, `json.parse[T](u)` which validates every
  field), and `u.trust(reason: "…")` (the reason satisfies SYN-018), listed by `egide audit`.
- **[SEC-003]** `Untrusted[T]` may be interpolated into sink templates (§12.2), which escape or parameterise it.
- **[SEC-004]** `Display` of `Untrusted[str]` prints an escaped, length-limited representation (log injection defence).

## 12.2 Sink types

| Type | Built by | Guarantee |
|------|----------|-----------|
| `Sql` | `sql"…"` | **[SEC-010]** every interpolation becomes a bound parameter; identifiers require `sql.ident(name)` validated against `[A-Za-z_][A-Za-z0-9_]*` |
| `Html` | `html"…"` | **[SEC-011]** contextual auto-escaping (element, attribute, URL, JS, CSS contexts), as Go's `html/template` |
| `Cmd` | `cmd"…"` | **[SEC-013]** program and arguments are separate `argv` entries; no shell is ever invoked; the program must be allowed by the `Proc` capability |
| `Url` | `url"…"` | **[SEC-014]** interpolations are percent-encoded per component; the scheme must be `https` unless written literally |
| `Path` | `path"…"` | **[SEC-015]** interpolated segments cannot contain `/`, `..` or NUL |
| `Regex` | `re"…"` | **[SEC-016]** compiled at compile time; linear-time engine (RE2 semantics), no backreferences |

- **[SEC-017]** Sink types have no constructor from `str` outside `unsafe`.

## 12.3 Secrets

- **[SEC-012]** `Secret[T]`:
  - `Display`, `Debug`, `Show`, `Json` and logging render `***`;
  - equality is constant-time (`ct_eq`); `Hash` is not implemented;
  - memory is zeroed on reclamation (non-optimisable) and locked (`mlock`) when available;
  - the value is reachable only through `s.expose(v => …)`; the lambda's result type MUST NOT contain `T` or anything
    derived from its storage (enforced by the `NoSecretEscape` marker on the result type).
- **[SEC-018]** `Secrets` capability sources: files (Kubernetes/External Secrets mounts), environment variables,
  HashiCorp Vault (`secrets.vault(path)` with the `egide.vault` package).

## 12.4 Cryptography and transport defaults

- **[SEC-020]** `std.crypto` exposes only: AES-GCM, ChaCha20-Poly1305, Ed25519, X25519, ECDSA P-256, RSA ≥ 3072 bits,
  HKDF, HMAC, SHA-2, SHA-3, BLAKE3, Argon2id. MD5, SHA-1, DES, RC4, ECB mode and RSA < 3072 live in
  `std.crypto.legacy`, whose import produces a warning.
- **[SEC-021]** TLS clients verify certificates and require TLS 1.2 or later by default. Disabling verification
  requires `unsafe`.
- **[SEC-022]** `Rand` is cryptographically secure. Fast non-cryptographic generators exist only as explicitly seeded
  values (`std.rand.fast(seed)`), which are pure.
- **[SEC-023]** Password hashing uses Argon2id with OWASP-recommended parameters by default.

## 12.5 Parsing and resource limits

- **[SEC-030]** Deserialisers (JSON, TOML, YAML, XML) never instantiate types chosen by the input (no polymorphic
  deserialisation) and enforce default limits: 10 MiB input, depth 128, 1 000 000 elements; limits are parameters.
- **[SEC-031]** The XML parser does not resolve external entities (no XXE). YAML supports only the safe subset
  (no tags, no anchors expansion bombs).
- **[SEC-032]** HTTP servers have default timeouts (header 10 s, body 60 s, idle 120 s) and a default maximum header
  size of 1 MiB.

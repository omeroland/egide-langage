---
id: Q-0041
rule: PKG-041
raised_by: tooling-engineer/T-1120
blocking: [T-1132, T-1134, T-1140]
status: open
---
## Question

Private registries and Sigstore trust roots. Go has `GOPRIVATE`, `GONOSUMDB`, `GOAUTH` for non-public code. PKG-041 forbids any bypass, but chapter 10 defines one public registry and no way to use a company registry or a different Sigstore root.

## Example

```toml
[registries.corp]
url = "https://registry.example.com"
signer = "https://github.com/example-corp"   # accepted Sigstore identity
```

## Options

A. Only the public registry. B. Additional registries declared in the manifest with an explicit accepted signer identity and root; verification identical, nothing optional. C. Per-user configuration outside the manifest.

## Recommendation

B: private code is a real need for the owner's target users (platform teams); the trust root must be in the reviewed manifest, not in an environment variable. Context: docs/toolchain-parity.md, ADR-0019 (Proposed).

# Rust vendoring compatibility

`fetch-cargo-vendor.nix` is shared by the simple Rust package overlay and
`scripts/source-build.sh`. It patches only nixpkgs' vendor assembly utility;
fixed-output staging downloads and existing `cargoHash` values are unchanged.

Cargo permits equal crate names and versions from different sources. The pinned
nixpkgs assembly utility combines these into one directory source, which cannot
represent that distinction. `cargo-vendor-sources.patch` gives each Git source
its own directory and source-replacement entry. Registry crates retain the
original directory source. Git source keys include branch/tag/rev selectors;
Cargo itself cannot independently replace two precise commits of the same
unqualified source key, so dependencies needing separate commits must use
separate selectors (for example, explicit `rev` values).

The wrapper asserts the expected utility is present and applies the patch with
no fuzz, so a future nixpkgs change fails visibly instead of silently dropping
the fix. Revisit/remove this workaround when nixpkgs handles source separation.

Hash updates must build the assembled vendor output with the discovered hash
before saving it: the expected staging hash mismatch does not validate assembly.

## Offline regression tests

From the repository root (requires Python 3.13+, Cargo and Nix):

```bash
util=$(nix build --impure --no-link --print-out-paths --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    p = f.nixosConfigurations.nixos-desktop.pkgs;
  in builtins.head p.clippier.cargoDeps.nativeBuildInputs
')
python3 pkgs/source-builds/test-vendor-sources.py "$util/bin/fetch-cargo-vendor-util"
```

The tests assemble local fixture dependencies, then run real Cargo resolution
with `--offline --locked`, checking that each source resolves to its own code:
registry-only, registry plus Git, and two explicit Git revisions.

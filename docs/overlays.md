# Overlays

Back to overview: `README.md`

All overlays live in `overlays/`. `overlays/default.nix` returns the ordered list applied to every host; each file is a plain `{ inputs }: final: prev: { … }` overlay (rust returns a list).

| File                    | Provides                                                                   |
| ----------------------- | -------------------------------------------------------------------------- |
| `unstable.nix`          | `pkgs.unstable` (nixpkgs-unstable) and `pkgs.fish` from unstable           |
| `darwin-fixes.nix`      | Darwin-only package fixes (ollama tests, fishPlugins.bass)                 |
| `firefox-darwin.nix`    | Firefox on macOS                                                           |
| `rust.nix`              | `rustStable`, `rustNightly`, `mkRust*`, `mkCargoWrapper`, `mkRustcWrapper` |
| `source-builds.nix`     | Auto-discovered Rust packages from `pkgs/source-builds/configs`            |
| `cronstrue.nix`         | `cronstrue-custom` (npm, complex build)                                    |
| `sendsafely-java.nix`   | `sendsafely-java` (Maven, complex build)                                   |
| `github-releases.nix`   | Auto-discovered release binaries from `pkgs/github-releases/configs`       |
| `minecraft-plugins.nix` | `pkgs.minecraftPlugins.*` from `pkgs/minecraft-plugins/configs`            |

Rule: attribute **names** an overlay defines must not depend on `final` (use `prev.lib` for helpers like `concatMapAttrs`), or evaluation recurses infinitely.

## 1) GitHub Release Binaries

Use for pre-built upstream release artifacts.

```bash
./scripts/github-release.sh add
./scripts/github-release.sh update --all
./scripts/github-release.sh check
```

Data locations:

- Configs: `pkgs/github-releases/configs/*.json`
- Version pins: `pkgs/github-releases/versions/*.json`
- Builder: `pkgs/github-releases/mk-github-release.nix`

## 2) Source-Built Packages

Use for packages built from source (Rust, npm, Maven).

```bash
nix flake lock
./scripts/source-build.sh check
./scripts/source-build.sh update --all
```

Data locations:

- Package configs: `pkgs/source-builds/configs/*.json`
- Hash pins: `pkgs/source-builds/hashes/*.json`

Hash files are part of the build contract and must be committed. `lib/locked-source.nix` throws at evaluation time if a hash file's `rev` does not match `flake.lock`.

### Add a Simple Source-Built Package

1. Add a flake input in `flake.nix` named `<name>-src` with `flake = false`
2. Add `pkgs/source-builds/configs/<name>.json`
3. Run `nix flake lock`
4. Run `./scripts/source-build.sh update <name>`
5. Reference `pkgs.<name>` in home config

For packages with custom build logic, set `"complex": true` and add a standalone file in `overlays/` that uses `lib/locked-source.nix`.

## More Details

- `scripts/README.md` documents full script options and workflows.

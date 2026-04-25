# Overlays

Back to overview: `README.md`

This repo supports two main custom package workflows.

## 1) GitHub Release Binaries

Use for pre-built upstream release artifacts.

```bash
./scripts/github-release.sh add
./scripts/github-release.sh update --all
./scripts/github-release.sh check
```

Data locations:

- Configs: `lib/github-releases/configs/*.json`
- Version pins: `lib/github-releases/versions/*.json`

Overlay entrypoint:

- `lib/overlays/github-releases.nix`

## 2) Source-Built Packages

Use for packages built from source (for example Rust or npm).

```bash
nix flake lock
./scripts/source-build.sh check
./scripts/source-build.sh update --all
```

Data locations:

- Package configs: `lib/source-builds/configs/*.json`
- Hash pins: `lib/source-builds/hashes/*.json`

Important: hash files are part of the build contract and should be committed.

## Add a Simple Source-Built Package

1. Add a flake input in `flake.nix` (`flake = false`)
2. Add `lib/source-builds/configs/<name>.json`
3. Run `nix flake lock`
4. Run `./scripts/source-build.sh update <name>`
5. Reference `pkgs.<name>` in host/home config

For packages with custom build logic, use a standalone overlay in `lib/overlays/`.

## More Details

- `scripts/README.md` documents full script options and workflows.

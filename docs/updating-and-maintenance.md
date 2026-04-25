# Updating and Maintenance

Back to overview: `README.md`

This page covers the normal update and rebuild workflow.

## Rebuild Workflow

Preferred:

```bash
./rebuild.sh --diff
./rebuild.sh
```

Manual alternatives:

```bash
# NixOS
sudo nixos-rebuild build --flake .#<host>
sudo nixos-rebuild switch --flake .#<host>

# Darwin
darwin-rebuild build --flake .#<host>
darwin-rebuild switch --flake .#<host>

# Standalone Home Manager
home-manager switch --flake .#<user>@<host>
```

## Update Inputs

```bash
# Update all flake inputs
nix flake update

# Update one input
nix flake update nixpkgs
```

After updating flake inputs, update source-build hashes when needed:

```bash
./scripts/source-build.sh check
./scripts/source-build.sh update --all
```

## One-Command Update Flow

```bash
./scripts/update-all.sh
```

This runs flake updates plus source-build and GitHub-release update steps.

## Formatting

```bash
./fmt.sh
./fmt.sh --check
```

## Cleanup

```bash
./scripts/clean.sh
```

## Script Reference

For full script usage and options, see `scripts/README.md`.

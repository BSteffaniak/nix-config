# Packages and Modules

Back to overview: `README.md`

This repo is home-manager-first for user tooling.

## Rule of Thumb

- If it is a user tool, put it in Home Manager (`home.packages`)
- If it needs system privileges or system integration, use system modules

## Module Hierarchy

System modules:

- `modules/common/`
- `modules/nixos/`
- `modules/darwin/`

Home Manager modules:

- `home/common/`
- `home/modules/`
- `home/nixos/`, `home/darwin/`, `home/standalone/` bridge layers

## Where to Add Packages

Preferred locations for user tools:

- CLI tools: `home/modules/cli-tools/`
- Dev tools/languages: `home/modules/development/`
- DevOps tools: `home/modules/devops/`
- User apps across hosts: `home/common/packages.nix`

System-level only when required:

- NixOS services/system features: `modules/nixos/`
- Darwin system settings/services: `modules/darwin/`

Host-specific overrides:

- `hosts/<host>/home.nix` for user-scoped host changes
- `hosts/<host>/default.nix` for system-scoped host changes

## Feature Flags

Configurable behavior is exposed under `myConfig.*` options.

```nix
options.myConfig.tools.encryption.enable = mkEnableOption "Encryption tools";
```

```nix
myConfig.tools.encryption.enable = true;
```

## Validate Changes

```bash
# Preview
./rebuild.sh --diff

# Apply
./rebuild.sh
```

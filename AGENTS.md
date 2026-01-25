# Agent Guidelines for Nix Configuration

This document provides guidance for AI agents and contributors working on this Nix configuration repository.

## Architecture Overview

This configuration manages multiple hosts across different platforms:

- **NixOS** (nixos-desktop) - Full NixOS system configuration
- **nix-darwin** (macbook-air, mac-studio) - macOS with nix-darwin
- **Standalone home-manager** (ubuntu-laptop) - Home-manager only on non-NixOS Linux

## Module Hierarchy

There are two distinct module hierarchies with different purposes:

### 1. System Modules (`modules/`)

Location: `modules/common/`, `modules/nixos/`, `modules/darwin/`

These modules use `environment.systemPackages` and system-level configuration options.

**When to use:**

- System services (tailscale, docker, etc.)
- Boot configuration
- Hardware drivers
- Network configuration
- System-wide settings that require root

**Limitations:**

- Not available on standalone home-manager setups (e.g., ubuntu-laptop)
- Requires system rebuild with elevated privileges

### 2. Home-Manager Modules (`home/modules/`)

Location: `home/modules/`, `home/common/`, `home/standalone/`

These modules use `home.packages` and home-manager configuration options.

**When to use:**

- User applications and CLI tools
- Development environments (Rust, Node.js, Go, Python, etc.)
- Shell configuration (fish, git, ssh)
- Editor configuration (neovim)
- Any package that doesn't require system-level access

**Advantages:**

- Portable across all host types including standalone home-manager
- User-scoped, no root required
- Consistent behavior regardless of underlying OS

## Key Principle: Prefer Home-Manager for User Tools

**Always prefer `home.packages` over `environment.systemPackages` for user-facing tools.**

Rationale:

1. **Portability** - Works on standalone home-manager setups that don't have access to system-level package installation
2. **Consistency** - Same configuration works across NixOS, nix-darwin, and standalone home-manager
3. **User-scoped** - Packages are installed per-user, avoiding conflicts and permission issues
4. **Faster iteration** - Home-manager rebuilds are faster than full system rebuilds

### Examples

**Good** - Using home-manager for user tools:

```nix
# home/modules/tools/default.nix
config = {
  home.packages = with pkgs;
    (optional cfg.archiving.enable _7zz)
    ++ (optional cfg.encryption.enable age);
};
```

**Avoid** - Using system packages for user tools:

```nix
# modules/common/tools/default.nix (DON'T DO THIS)
config = {
  environment.systemPackages = with pkgs; [
    _7zz
    age
  ];
};
```

## Configuration Options Pattern

All configurable features use the `myConfig.*` option namespace:

```nix
# Defining options (in module)
options.myConfig.tools.archiving.enable = mkEnableOption "Archive tools (7-zip)";

# Using options (in host config)
myConfig.tools.archiving.enable = true;
```

## Host Configuration Structure

Each host has two configuration files:

- `hosts/<hostname>/default.nix` - System-level configuration (NixOS/nix-darwin options)
- `hosts/<hostname>/home.nix` - User-level configuration (home-manager options)

**System config (`default.nix`)** should contain:

- Hardware configuration
- Boot settings
- System services
- Network configuration
- System packages that truly require system-level installation

**Home config (`home.nix`)** should contain:

- User applications
- Development tools
- Shell and editor preferences
- CLI utilities
- Personal tool configurations

## Adding New Packages

When adding a new package to the configuration:

1. **Determine scope**: Is this a system service or a user tool?
2. **Choose location**:
   - User tool → `home/modules/` with `home.packages`
   - System service → `modules/` with appropriate system options
3. **Create feature flag**: Add `myConfig.*.enable` option
4. **Update host configs**: Enable the feature in relevant `home.nix` files

## Testing Changes

Always test changes by building before switching:

```bash
# For nix-darwin (macOS)
darwin-rebuild build --flake .#<hostname>

# For NixOS
nixos-rebuild build --flake .#<hostname>

# For standalone home-manager
home-manager build --flake .#<user>@<hostname>
```

## Common Patterns

### Feature flags with mkEnableOption

```nix
options.myConfig.tools.encryption.enable = mkEnableOption "Encryption tools (age)";
```

### Conditional package installation

```nix
home.packages = optional cfg.encryption.enable pkgs.age;
```

### Multiple packages from one flag

```nix
home.packages = mkIf cfg.ai.enable [
  pkgs.unstable.gemini-cli
  pkgs.ollama
];
```

### Using unstable channel

```nix
home.packages = [ pkgs.unstable.some-package ];
```

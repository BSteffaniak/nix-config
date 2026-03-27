# Agent Guidelines for Nix Configuration

This document provides guidance for AI agents and contributors working on this Nix configuration repository.

## Architecture Overview

This configuration manages multiple hosts across different platforms:

- **NixOS** (nixos-desktop) - Full NixOS system configuration
- **nix-darwin** (macbook-air, mac-studio, bs-mbpro) - macOS with nix-darwin
- **Standalone home-manager** (ubuntu-laptop) - Home-manager only on non-NixOS Linux

### Host Auto-Discovery

Hosts are **automatically discovered** from `hosts/*/meta.nix` files. The `flake.nix` scans the `hosts/` directory at evaluation time and generates the appropriate `nixosConfigurations`, `darwinConfigurations`, `homeConfigurations`, and `devShells` outputs based on each host's `meta.nix`. Neither `flake.nix` nor `rebuild.sh` need manual edits when adding or removing hosts.

### Host Builder Helpers

Platform-specific boilerplate is factored into reusable builder functions:

- `lib/mkDarwinHost.nix` - Creates a nix-darwin system configuration
- `lib/mkNixosHost.nix` - Creates a NixOS system configuration
- `lib/mkHomeConfig.nix` - Creates a standalone home-manager configuration

### Private Hosts (git-crypt)

Some host directories (e.g., `hosts/bs-mbpro/`) are encrypted via **git-crypt**. On GitHub they appear as binary blobs. On machines with the git-crypt key unlocked, they are transparent. Encryption rules are defined in `.gitattributes`.

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

Location: `home/modules/`, `home/common/`, `home/standalone/`, `home/darwin/`, `home/nixos/`

The `home/darwin/` and `home/nixos/` directories are platform-specific bridge modules that wire system-level options into the home-manager configuration for their respective platforms.

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

Each host directory contains the following files:

- `hosts/<hostname>/meta.nix` - **(required)** Host metadata for auto-discovery (type, system, hostname, username)
- `hosts/<hostname>/default.nix` - **(NixOS/nix-darwin only)** System-level configuration
- `hosts/<hostname>/home.nix` - **(required)** User-level configuration (home-manager options)

Standalone home-manager hosts (e.g., `ubuntu-laptop`) only need `meta.nix` and `home.nix` -- no `default.nix` is required since there is no system-level configuration to manage.

**Metadata (`meta.nix`)** declares:

```nix
{
  type = "darwin";         # "nixos" | "darwin" | "home-manager"
  system = "aarch64-darwin";
  hostname = "Bradens-MacBook-Air";  # As reported by `hostname` command
  username = "braden";
  # Optional: extra NixOS modules (e.g., ["nix-minecraft"])
  # extraModules = [];
}
```

**System config (`default.nix`)** should contain (NixOS/nix-darwin hosts only):

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

### Adding Source-Built Packages

For packages built from Git source (not in nixpkgs), use the **auto-discovery source-build system**. Simple Rust packages require only:

1. Add a flake input to `flake.nix`:
   ```nix
   my-tool-src = { url = "github:someone/my-tool"; flake = false; };
   ```
2. Create `lib/source-builds/configs/my-tool.json`:
   ```json
   {
     "flakeInput": "my-tool-src",
     "buildSystem": "rust",
     "pname": "my-tool",
     "hashField": "cargoHash"
   }
   ```
3. Run `nix flake lock && ./scripts/source-build.sh update my-tool`
4. Use `pkgs.my-tool` in your host config

No other Nix files need editing. The auto-discovery overlay (`lib/overlays/source-builds.nix`) picks up configs automatically, similar to how `github-releases.nix` and `minecraft-plugins.nix` work.

**Optional config fields:** `doCheck` (default `true`), `cargoBuildFlags` (array), `cargoLockFile` (for repos without `Cargo.lock`).

**Complex builds** (custom toolchains, build phases, `nativeBuildInputs`, etc.) should set `"complex": true` in the config JSON and use a standalone overlay file in `lib/overlays/`. See `zellij.nix` and `cronstrue.nix` for examples.

## Adding New Hosts

To add a new host, create a directory under `hosts/` with these files:

1. `hosts/<name>/meta.nix` - Metadata (type, system, hostname, username)
2. `hosts/<name>/default.nix` - System configuration (NixOS/nix-darwin hosts only)
3. `hosts/<name>/home.nix` - Home-manager configuration

For standalone home-manager hosts, `default.nix` is not needed.

No other files need editing. The flake auto-discovers the host from `meta.nix`, and `rebuild.sh` matches the hostname automatically.

Alternatively, run `./bootstrap.sh` for an interactive setup.

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
# home/modules/cli-tools/utilities.nix
home.packages = mkIf cfg.opencode.enable [
  pkgs.unstable.opencode
  pkgs.unstable.claude-code
];
```

### Using unstable channel

```nix
home.packages = [ pkgs.unstable.some-package ];
```

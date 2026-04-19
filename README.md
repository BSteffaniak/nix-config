# Nix Configuration

Modular, cross-platform Nix configuration supporting **NixOS**, **macOS (nix-darwin)**, and **standalone systems (Ubuntu, etc.)** via Home Manager.

## Architecture Overview

This repository uses a **home-manager-first architecture** that enables:

- ✅ Full NixOS system configurations
- ✅ macOS (Darwin) system configurations with Homebrew
- ✅ **Standalone home-manager** for Ubuntu and other Linux distros
- ✅ Consistent development environments across all platforms
- ✅ Rootless containers (Podman) without system-level Docker

## Flake Design

This repository uses a **unified flake** at the root that provides:

- **NixOS configurations** (`nixosConfigurations`) - Full system configurations for NixOS
- **Darwin configurations** (`darwinConfigurations`) - macOS system configurations with Homebrew
- **Standalone home-manager** (`homeConfigurations`) - For Ubuntu and other Linux distros

**Benefits:**

- ✅ Single `flake.lock` - all platforms use identical package versions
- ✅ Add inputs once, available everywhere
- ✅ No version drift between platforms
- ✅ Simplified overlay management

## Structure

```
.
├── flake.nix                # Unified flake for all platforms
├── flake.lock               # Single lock file for consistent versions
├── rebuild.sh               # Auto-detecting rebuild script
├── bootstrap.sh             # Interactive new host setup
├── install-config.sh        # Standalone config installer
│
├── hosts/                   # Per-machine configurations (auto-discovered)
│   ├── nixos-desktop/       # NixOS desktop PC
│   ├── macbook-air/         # MacBook Air (Apple Silicon)
│   ├── mac-studio/          # Mac Studio
│   ├── bs-mbpro/            # Work MacBook Pro (git-crypt encrypted)
│   └── ubuntu-laptop/       # Ubuntu with standalone home-manager
│
├── modules/                 # System-level modules (NixOS/nix-darwin)
│   ├── common/              # Cross-platform system modules
│   │   ├── development/     # Dev toolchains (rust, node, go, python, etc.)
│   │   ├── shell/           # Shell configuration (fish/bash/zsh/nushell, git)
│   │   ├── editors/         # Text editors (neovim)
│   │   └── services/        # System services (tailscale)
│   │
│   ├── nixos/               # NixOS-specific modules
│   │   ├── boot/            # Boot configuration
│   │   ├── hardware/        # Hardware support (nvidia, graphics)
│   │   ├── desktop/         # Desktop environment (hyprland, waybar, gtk)
│   │   ├── services/        # System services (docker, observability, minecraft)
│   │   └── system/          # System configuration (networking, security, audio)
│   │
│   └── darwin/              # macOS-specific modules (21 files)
│       ├── homebrew.nix     # Homebrew integration
│       ├── system-defaults.nix  # macOS system preferences
│       ├── aerospace.nix    # Window manager
│       ├── security.nix     # Security settings
│       └── ...              # Application modules, services, etc.
│
├── home/                    # Home Manager configurations
│   ├── common/              # Cross-platform home config
│   ├── modules/             # Feature-flagged home-manager modules
│   │   ├── cli-tools/       # CLI utilities (fzf, ripgrep, jq, etc.)
│   │   ├── containers/      # Podman, distrobox
│   │   ├── development/     # Dev tools (lazygit, act, language support)
│   │   ├── devops/          # DevOps tools (kubectl, helm, terraform, etc.)
│   │   ├── desktop/         # Desktop apps (hyprland, waybar, etc.)
│   │   ├── editors/         # Editor configurations (neovim)
│   │   ├── design/          # Design tools
│   │   ├── shell/           # Shell utilities (bat, eza, zoxide, etc.)
│   │   ├── tools/           # Misc tools (7zip, age, ollama, etc.)
│   │   ├── fish.nix         # Fish shell features/integration
│   │   ├── git.nix          # Git configuration
│   │   └── gtk-theming.nix  # GTK theming (opt-in)
│   ├── nixos/               # NixOS-specific home bridge
│   ├── darwin/              # macOS-specific home bridge
│   └── standalone/          # Standalone home-manager (Ubuntu, etc.)
│
├── configs/                 # Portable standalone configs (usable without Nix)
│   ├── neovim/              # Neovim editor
│   ├── tmux/                # Tmux terminal multiplexer
│   ├── ghostty/             # Ghostty terminal emulator
│   └── ...                  # 19 configs total (see Standalone section)
│
├── lib/                     # Helper functions and overlays
│   ├── mkDarwinHost.nix     # Darwin host builder
│   ├── mkNixosHost.nix      # NixOS host builder
│   ├── mkHomeConfig.nix     # Standalone home-manager builder
│   ├── mkOverlays.nix       # Overlay orchestration
│   ├── overlays/            # Individual overlay definitions
│   ├── github-releases/     # GitHub release binary packages
│   ├── source-builds/       # Source-built package hashes
│   └── minecraft-plugins/   # Minecraft plugin packages
│
├── packages/                # Custom packages (display-ctl, etc.)
│
└── scripts/                 # Helper scripts
    ├── update-all.sh        # One-command full update helper
    ├── github-release.sh    # Manage GitHub release overlays
    ├── source-build.sh      # Manage source-built package hashes
    ├── detect-hardware.sh   # NixOS hardware detection
    ├── new-host-template.sh # Host template generator
    └── setup-git-crypt.sh   # git-crypt setup helper
```

## Standalone Config Installation

All configurations in `configs/` are portable and can be used **without Nix** on any system (Windows, Linux, macOS).

### Quick Install (Any Config, Any OS)

Using the helper script:

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/BSteffaniak/nix-config/master/install-config.sh | bash -s neovim

# Or clone and use locally
git clone https://github.com/BSteffaniak/nix-config.git
cd nix-config
./install-config.sh neovim
```

### Manual Install (Git Sparse Checkout)

```bash
# Clone with sparse checkout (downloads only what you need)
git clone --filter=blob:none --sparse https://github.com/BSteffaniak/nix-config.git
cd nix-config

# Checkout specific config
git sparse-checkout set configs/neovim

# Copy to your system
cp -r configs/neovim ~/.config/nvim
```

### Available Standalone Configs

- `neovim` - Neovim editor with lazy.nvim and LSP
- `hyprland` - Hyprland window manager
- `waybar` - Waybar status bar
- `ghostty` - Ghostty terminal emulator
- `tmux` - Tmux terminal multiplexer with plugins
- `wezterm` - WezTerm terminal emulator
- `zellij` - Zellij terminal workspace
- `lazygit` - LazyGit TUI
- `bottom` - Bottom system monitor
- `gh` - GitHub CLI and gh-dash
- `opencode` - OpenCode AI assistant configuration
- `lspmux` - LSP multiplexer
- `fuzzel` - Fuzzel application launcher
- `waypaper` - Waypaper wallpaper manager
- `act` - GitHub Actions locally
- `htop` - htop system monitor
- `aerospace` - AeroSpace window manager (macOS)
- `sledge` - Sledge keyboard remap daemon (macOS)
- `sketchybar` - SketchyBar status bar (macOS)

Each config works standalone and can be cloned/used independently.

## Quick Start

The `rebuild.sh` script automatically detects your platform and uses the correct flake.

```bash
# Compare changes before rebuilding (recommended!)
./rebuild.sh --diff

# Auto-detect and rebuild
./rebuild.sh

# Boot into new config (NixOS only)
./rebuild.sh --boot

# On NixOS: uses #nixos-desktop
# On Darwin: uses #macbook-air or #mac-studio
# On Ubuntu: use home-manager switch --flake .#braden@ubuntu-laptop
```

### Diff Mode (Preview Changes)

The `--diff` (or `--compare`) flag builds your configuration and shows what would change **without applying** it:

```bash
# See what would change
./rebuild.sh --diff

# Output shows:
# - New packages being added
# - Packages being updated (with version changes)
# - Packages being removed
# - Total closure size change

# Then apply if you like the changes
./rebuild.sh
```

This uses `nvd` (nix version diff) to provide a clear summary of changes. If `nvd` isn't installed, it falls back to `nix store diff-closures`.

### Manual Usage

**NixOS:**

```bash
# Build without applying
sudo nixos-rebuild build --flake .#nixos-desktop

# Apply configuration
sudo nixos-rebuild switch --flake .#nixos-desktop

# Boot into new config (safer)
sudo nixos-rebuild boot --flake .#nixos-desktop
```

**macOS (Darwin):**

```bash
# Build without applying
darwin-rebuild build --flake .#macbook-air

# Apply configuration
darwin-rebuild switch --flake .#macbook-air
```

**Ubuntu/Standalone:**

```bash
# Apply standalone home-manager configuration
home-manager switch --flake .#braden@ubuntu-laptop
```

## Available Hosts

### NixOS Systems

- **nixos-desktop**: NixOS desktop PC with NVIDIA GPU, Hyprland, development tools

### macOS Systems

- **macbook-air**: MacBook Air (Apple Silicon) with development tools
- **mac-studio**: Mac Studio with development tools

### macOS Systems (Private)

- **bs-mbpro**: Work MacBook Pro (git-crypt encrypted configuration)

### Standalone Home Manager (Ubuntu, etc.)

- **ubuntu-laptop**: Ubuntu laptop with home-manager only

## Using on Ubuntu or Other Linux Distros

This configuration can be used on Ubuntu or any Linux distro via standalone home-manager!

**Quick start:**

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Clone this repo
git clone <your-repo-url> ~/.config/nix

# Apply the configuration
nix run home-manager/release-25.11 -- switch --flake ~/.config/nix#braden@ubuntu-laptop
```

**What you get:**

- All development tools (Rust, Node.js, Go, Python, etc.)
- Rootless Podman for containers (Docker-compatible!)
- DevOps tools (kubectl, helm, terraform, aws-cli)
- Complete shell setup (fish/bash/zsh/nushell, git, ssh, neovim)
- All CLI utilities
- No sudo required for package management!

## Customization

Each host can enable/disable features via the `myConfig` options in `hosts/*/default.nix` (system-level) and `hosts/*/home.nix` (user-level):

```nix
myConfig = {
  # Development
  development.rust.enable = true;
  development.nodejs.enable = true;
  development.go.enable = true;
  development.dotnet.enable = true;

  # Desktop (NixOS only)
  desktop.hyprland.enable = true;

  # Services
  services.docker.enable = true;

  # etc...
};
```

### Multi-Shell Configuration

Shell behavior can be shared across Fish, Bash, Zsh, and Nushell from one place.
The global default shell is set in `lib/default.nix`.

```nix
myConfig.shell = {
  default = "nushell"; # optional per-host override

  fish.enable = true;
  bash.enable = true;
  zsh.enable = true;
  nushell.enable = true;

  shared.aliases = {
    k = "kubectl";
    tf = "tofu";
  };
};
```

### .NET Development

The .NET module provides comprehensive support for .NET development with flexible configuration options:

**Simple SDK (latest stable):**

```nix
myConfig = {
  development.dotnet.enable = true;
  # Uses .NET SDK 8.x by default with Entity Framework tools
};
```

**Multiple SDK versions:**

```nix
myConfig = {
  development.dotnet.enable = true;
  development.dotnet.sdkVersions = [ "8" "9" ];  # Install multiple versions
  development.dotnet.entityFramework.enable = true;
};
```

**Runtime-only (for deployment/production):**

```nix
myConfig = {
  development.dotnet.enable = true;
  development.dotnet.runtimeOnly = true;
  development.dotnet.runtimeVersions = [ "8" ];
  development.dotnet.aspnetcore.enable = true;
  development.dotnet.aspnetcore.versions = [ "8" ];
};
```

**Full development setup:**

```nix
myConfig = {
  development.dotnet.enable = true;
  development.dotnet.sdkVersions = [ "8" "9" ];

  # ASP.NET Core
  development.dotnet.aspnetcore.enable = true;
  development.dotnet.aspnetcore.versions = [ "8" "9" ];

  # Tools
  development.dotnet.entityFramework.enable = true;
  development.dotnet.globalTools = {
    enableOutdated = true;      # dotnet-outdated
    enableRepl = true;           # Interactive C# REPL
    enableFormatters = true;     # CSharpier, Fantomas
    enablePaket = false;         # Paket dependency manager
  };

  # Custom NuGet sources
  development.dotnet.nuget = {
    enableCustomSources = true;
    sources = {
      "myget" = "https://www.myget.org/F/my-feed/api/v3/index.json";
      "github" = "https://nuget.pkg.github.com/myorg/index.json";
    };
  };
};
```

**F# development:**

```nix
myConfig = {
  development.dotnet.enable = true;
  development.dotnet.sdkVersions = [ "9" ];
  development.dotnet.globalTools = {
    enableFormatters = true;  # Includes Fantomas for F#
    enablePaket = true;       # Popular in F# community
  };
};
```

**Available options:**

- **`sdkVersions`**: List of SDK versions (`"6"`, `"7"`, `"8"`, `"9"`, `"10"`)
- **`runtimeOnly`**: Install only runtime (no SDK)
- **`runtimeVersions`**: Runtime versions when `runtimeOnly = true`
- **`aspnetcore.enable`**: Install ASP.NET Core runtime
- **`aspnetcore.versions`**: Specific ASP.NET Core versions
- **`entityFramework.enable`**: Install Entity Framework Core tools (default: true)
- **`globalTools.enableOutdated`**: Install dotnet-outdated
- **`globalTools.enableRepl`**: Install dotnet-repl (C# REPL)
- **`globalTools.enableFormatters`**: Install CSharpier and Fantomas
- **`globalTools.enablePaket`**: Install Paket dependency manager
- **`nuget.enableCustomSources`**: Enable custom NuGet sources
- **`nuget.sources`**: Attribute set of custom NuGet sources
- **`nuget.configFile`**: Path to custom NuGet.Config file

## Adding Custom Overlays

### GitHub Release Binaries (Recommended for Pre-Built Tools)

The simplest way to add a bleeding-edge binary from any GitHub project. No Nix file edits required — the overlay auto-discovers projects from config files.

**Quick start:**

```bash
# Interactive wizard
./scripts/github-release.sh add

# Or non-interactive
./scripts/github-release.sh add --non-interactive \
    --owner junegunn --repo fzf --pname fzf-bleeding
```

The script will:

1. Fetch the latest release from GitHub
2. Auto-detect platform-to-asset mapping
3. Create a config in `lib/github-releases/configs/<name>.json`
4. Fetch version data with sha256 hashes into `lib/github-releases/versions/<name>.json`

Then add `pkgs.<pname>` to your `home.nix` and rebuild. That's it.

**Updating versions:**

```bash
./scripts/github-release.sh update --all    # Update all projects
./scripts/github-release.sh update opencode # Update one project
./scripts/github-release.sh check           # Dry-run: check for updates
```

After updating, commit the changed `versions/*.json` files so all machines get the same versions.

**How it works:**

The auto-discovery overlay (`lib/overlays/github-releases.nix`) scans all config files in `lib/github-releases/configs/` and creates a Nix package for each one using the shared builder `lib/github-releases/mkGitHubRelease.nix`. The builder handles archive extraction (tar.gz/zip), binary installation, and Linux `autoPatchelfHook` automatically.

See `./scripts/github-release.sh --help` and `scripts/README.md` for full documentation.

### Source-Built Overlays (For Building from Source)

For packages that need to be built from source via a flake input.

#### Dependency Hash Management

Source-built packages using `buildNpmPackage` or `buildRustPackage` require dependency hashes (`npmDepsHash`, `cargoHash`) that go stale when upstream lock files change. Instead of manually updating these hashes, use the automated hash management system:

```bash
# After updating flake inputs
nix flake update
./scripts/source-build.sh check            # See which hashes are stale
./scripts/source-build.sh update --all     # Recompute all stale hashes
```

The overlays read hashes from `lib/source-builds/hashes/<name>.json` and validate the git rev at evaluation time. If you forget to update hashes after a flake update, you get a clear error telling you exactly what to run.

Currently managed packages: `cronstrue` (npm), `lspmux` (Rust), `zellij` (Rust).

See `./scripts/source-build.sh --help` and `scripts/README.md` for full documentation.

#### Adding a New Source-Built Overlay

##### Step 1: Add Input to Flake

Edit `flake.nix` and add your input:

```nix
inputs = {
  # ... existing inputs

  my-package = {
    url = "github:user/my-package";
    flake = false;
  };
};
```

##### Step 2: Create Overlay File

Create `lib/overlays/my-package.nix`:

```nix
{
  inputs,
  enable,
  mkGitInput,
}:
final: prev:
if !enable then
  { }
else
  let
    src = inputs.my-package;
    gitMeta = mkGitInput "my-package";
  in
  {
    my-package = prev.stdenv.mkDerivation {
      pname = "my-package";
      version = gitMeta.version;
      inherit src;
      # ... build instructions
    };
  }
```

##### Step 3: Register Overlay

Edit `lib/overlays.nix`:

```nix
# Import all overlay functions
overlayFunctions = {
  rust = import ./overlays/rust.nix;
  github-releases = import ./overlays/github-releases.nix;
  # ... existing overlays
  myPackage = import ./overlays/my-package.nix;  # Add this line
};
```

Edit `lib/mkOverlays.nix`:

```nix
mkOverlays =
  {
    enableRust ? true,
    enableGithubReleases ? true,
    # ... existing enables
    enableMyPackage ? true,  # Add this line
  }:
  [
    # ... existing overlay calls
    (overlayFunctions.myPackage { inherit inputs mkGitInput; enable = enableMyPackage; })
  ];
```

##### Step 4: Update Flake to Pass Input

Edit `flake.nix` in the `mkOverlays` function:

```nix
mkOverlays = system: nixpkgsLib: import ./lib/overlays.nix {
  inherit (nixpkgsLib) lib;
  inherit nixpkgs-unstable;
  # ... existing inputs
  my-package-src = inputs.my-package;  # Add this
  # ...
};
```

##### That's It!

Run `nix flake update` and your overlay is available on **all platforms** automatically!

**Total files modified:** 4 (down from 9+ with the old multi-flake approach)

## Adding Packages

This repository follows a **home-manager-first architecture**. Always prefer `home.packages` over `environment.systemPackages` for user-facing tools. This ensures packages work across all hosts, including standalone home-manager setups.

### User Tools and CLI Utilities (Preferred)

**CLI Tools:**

- **Location:** `home/modules/cli-tools/` (utilities, file tools, monitoring, formatters, terminals)
- **Use for:** Command-line utilities (fzf, ripgrep, jq, htop, etc.)
- **Example:**
  ```nix
  # home/modules/cli-tools/utilities.nix
  home.packages = mkIf cfg.jq.enable [ pkgs.jq ];
  ```

**Development Tools:**

- **Location:** `home/modules/development/` (language-specific files)
- **Use for:** Dev tools, language support, build helpers
- **Example:**
  ```nix
  # home/modules/development/lazygit.nix
  home.packages = mkIf cfg.enable [ pkgs.lazygit ];
  ```

**DevOps Tools:**

- **Location:** `home/modules/devops/`
- **Use for:** Infrastructure and cloud tools (kubectl, helm, terraform, aws-cli, etc.)

**User Applications:**

- **Location:** `home/common/packages.nix`
- **Use for:** Personal applications, user-specific packages
- **Scope:** Installed for your user across all platforms
- **Example:**
  ```nix
  home.packages = with pkgs; [
    # ... existing packages
    spotify  # Add desktop app
  ];
  ```

### System-Level Packages (When Required)

Only use `environment.systemPackages` for things that genuinely need system-level access (services, drivers, boot config). These are **not available** on standalone home-manager hosts.

**System services and toolchains:**

- **Location:** `modules/common/development/` (language toolchains shared at system level)
- **Location:** `modules/nixos/services/` (NixOS system services)
- **Location:** `modules/darwin/*.nix` (macOS-specific system config)

**NixOS Only:**

- **Location:** Appropriate module in `modules/nixos/*/`
  - Desktop apps: `modules/nixos/desktop/*.nix`
  - System services: `modules/nixos/services/*.nix`

**Single Host Only:**

- **Location:** `hosts/<hostname>/home.nix` (user tools) or `hosts/<hostname>/default.nix` (system-level)
- **Use for:** Machine-specific packages

### Quick Decision Guide

| I want to add...                   | Where?                                         |
| ---------------------------------- | ---------------------------------------------- |
| CLI tool for all machines          | `home/modules/cli-tools/`                      |
| Language/dev tool                  | `home/modules/development/`                    |
| DevOps tool (kubectl, terraform)   | `home/modules/devops/`                         |
| Desktop app for me (all platforms) | `home/common/packages.nix`                     |
| NixOS desktop tool                 | `modules/nixos/desktop/*.nix`                  |
| macOS-specific app                 | `home/darwin/default.nix`                      |
| System service (docker, tailscale) | `modules/nixos/services/` or `modules/darwin/` |
| Testing on one machine only        | `hosts/<hostname>/home.nix`                    |

### After Adding Packages

1. Preview changes before applying:

   ```bash
   ./rebuild.sh --diff
   ```

2. Apply if satisfied:
   ```bash
   ./rebuild.sh
   ```

**Alternative (manual):**

```bash
# Build without applying
sudo nixos-rebuild build --flake .#nixos-desktop  # NixOS
# or
darwin-rebuild build --flake .#macbook-air  # Darwin

# Compare what changed
nvd diff /run/current-system ./result

# Apply
./rebuild.sh
```

## Adding a New Host

### Interactive Bootstrap (Recommended)

Use the interactive bootstrap script to set up a new host configuration:

```bash
./bootstrap.sh
```

This script will:

- Detect your platform (NixOS or Darwin) and architecture
- Guide you through selecting which features to enable
- Generate `meta.nix`, `default.nix`, and `home.nix` in `hosts/<hostname>/`
- For NixOS: copy or generate `hardware-configuration.nix`

The flake and `rebuild.sh` auto-discover the new host from `meta.nix` -- no manual edits needed.

The bootstrap script asks about:

- **Development tools**: Rust, Node.js, Go, Python, Java, Zig, Android SDK, DevOps tools
- **Desktop environment** (NixOS only): Hyprland, Waybar, GTK, X Server
- **Hardware support** (NixOS only): NVIDIA GPU, graphics, audio
- **System services**: Docker, Podman, Minecraft server, observability
- **Shell & editors**: Fish/Bash/Zsh/Nushell, default shell, Neovim (with optional nightly builds), Git config

### Hardware Detection (NixOS)

Before bootstrapping a NixOS host, you can run the hardware detection script:

```bash
./scripts/detect-hardware.sh
```

This will detect your CPU, GPU, audio, network hardware, and provide configuration suggestions.

### Manual Setup

If you prefer to set up a host manually:

1. Create a new directory in `hosts/` (e.g., `hosts/new-laptop/`)
2. Create `hosts/new-laptop/meta.nix` with host metadata (type, system, hostname, username)
3. Create `hosts/new-laptop/home.nix` with home-manager configuration
4. For NixOS/nix-darwin hosts, also create `hosts/new-laptop/default.nix` with system configuration

No other files need editing. The flake auto-discovers hosts from `meta.nix`, and `rebuild.sh` matches the hostname automatically.

## Module System

All modules use NixOS module system options for configurability:

- **Common modules**: Available on all platforms
- **NixOS modules**: Linux-specific features
- **Darwin modules**: macOS-specific features

This allows sharing development tools, shell configurations, and CLI utilities across all machines while keeping platform-specific features separate.

### System vs User Packages

- **System packages** (`environment.systemPackages`): Available to all users, requires system rebuild. Use for services, drivers, and system-level tools only.
- **User packages** (`home.packages`): Installed per-user via Home Manager. **Preferred** for CLI tools, dev tools, and applications.
- **Rule of thumb**: If it doesn't need root or system-level access, use `home.packages`.

## Home Manager Configuration

Home Manager configurations are organized to be generic and reusable across hosts:

```
home/
├── common/              # Shared cross-platform user config
│   ├── git.nix         # Git configuration
│   ├── shell.nix       # Shell setup
│   └── packages.nix    # User packages
├── modules/             # Feature-flagged home-manager modules
│   ├── cli-tools/      # CLI utilities (fzf, ripgrep, jq, etc.)
│   ├── containers/     # Podman, distrobox
│   ├── development/    # Dev tools (lazygit, language support, etc.)
│   ├── devops/         # DevOps tools (kubectl, helm, terraform, etc.)
│   ├── desktop/        # Desktop apps (hyprland, waybar, etc.)
│   ├── editors/        # Editor configurations (neovim)
│   ├── design/         # Design tools
│   ├── shell/          # Shell utilities (bat, eza, zoxide, etc.)
│   ├── tools/          # Misc tools (7zip, age, ollama, etc.)
│   ├── fish.nix        # Fish shell features/integration
│   ├── git.nix         # Git configuration
│   └── gtk-theming.nix # GTK theming (opt-in)
├── nixos/               # NixOS-specific home bridge
│   └── default.nix
├── darwin/              # macOS-specific home bridge
│   └── default.nix
└── standalone/          # Standalone home-manager (Ubuntu, etc.)
    ├── default.nix
    └── ubuntu.nix
```

### Key Principles

**Generic Base Configs:**

- `home/nixos/default.nix` and `home/darwin/default.nix` are platform-specific bridges
- They import `home/common/` and `home/modules/` and wire system-level options into home-manager
- No personal preferences or hardcoded values
- Safe to use when bootstrapping new hosts

**Personal Overrides:**

- Create `hosts/<hostname>/home.nix` for host-specific home-manager config
- Contains your personal preferences (themes, packages, etc.)
- Not copied when bootstrapping new hosts

**Example: Personal GTK Theming**

Enable optional GTK theming in your host-specific home config:

```nix
# hosts/nixos-desktop/home.nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable GTK theming with personal preferences
  homeModules.gtkTheming = {
    enable = true;
    theme = "Juno";
    themePackage = pkgs.juno-theme;
    iconTheme = "Papirus-Dark";
    iconThemePackage = pkgs.papirus-icon-theme;
    cursorTheme = "Bibata-Modern-Classic";
    cursorThemePackage = pkgs.bibata-cursors;
    font = {
      name = "TeX Gyre Adventor";
      size = 10;
    };
  };

  # Personal packages
  home.packages = with pkgs; [
    steam
  ];
}
```

Host-specific `home.nix` files are automatically imported by the host builder helpers (`lib/mkNixosHost.nix`, `lib/mkDarwinHost.nix`, `lib/mkHomeConfig.nix`) alongside the platform bridge modules.

## Updating

**All Platforms (Unified Flake):**

```bash
# Update all inputs (affects all platforms)
nix flake update

# Update specific input
nix flake update nixpkgs          # NixOS packages
nix flake update nixpkgs-darwin   # macOS packages
nix flake update rust-overlay     # Rust toolchain

# Apply updates
./rebuild.sh
```

**Note:** The unified flake means updating packages updates them for **all platforms** consistently. No more version drift!

## Helper Scripts

### `rebuild.sh`

Auto-detecting rebuild script that identifies your host and uses the correct flake configuration. Supports preview mode to see changes before applying.

**Usage:**

```bash
# Preview changes before rebuilding
./rebuild.sh --diff

# Apply changes
./rebuild.sh

# Boot into new config (NixOS only)
./rebuild.sh --boot

# Pass additional nix flags
./rebuild.sh --diff --show-trace
```

**Features:**

- Automatically detects hostname and selects correct flake
- `--diff` or `--compare` mode builds configuration and shows changes using nvd
- Falls back to `nix store diff-closures` if nvd is not available
- Supports all standard nixos-rebuild/darwin-rebuild flags

### `fmt.sh`

Format all Nix files in the repository using nixfmt. Supports check mode for CI/pre-commit hooks.

**Usage:**

```bash
# Format all Nix files
./fmt.sh

# Check if files are formatted (exits 1 if formatting needed)
./fmt.sh --check
```

**Features:**

- Formats all 107+ `.nix` files in the repository
- Excludes `.git/` and `result*` build artifacts
- Color-coded output showing progress
- Check mode for CI/CD pipelines
- Summary statistics at the end

### `scripts/update-all.sh`

Unified updater for everything that normally needs to be run separately.

**Default flow:**

```bash
./scripts/update-all.sh
```

Runs, in order:

1. `nix flake update`
2. `./scripts/source-build.sh update --all`
3. `./scripts/github-release.sh update --all`

Useful options:

```bash
./scripts/update-all.sh --yes        # Skip confirmation
./scripts/update-all.sh --no-github  # Skip GitHub release updates
./scripts/update-all.sh --no-source  # Skip source-build hash updates
./scripts/update-all.sh --no-flake   # Skip flake input updates
```

After completion, it prints `git status --short` so you can review changed files quickly.

### `bootstrap.sh`

Interactive script for creating new host configurations. Guides you through all configuration options and generates everything needed for a new host.

**Usage:**

```bash
./bootstrap.sh
```

### `scripts/detect-hardware.sh`

Detects hardware on NixOS systems and suggests appropriate configuration options. Identifies GPU (NVIDIA/AMD/Intel), CPU, audio hardware, network devices, Bluetooth, storage, and virtualization.

**Usage:**

```bash
./scripts/detect-hardware.sh
```

### `scripts/new-host-template.sh`

Template generator called by `bootstrap.sh`. Can be used standalone to generate host configurations programmatically.

**Usage:**

```bash
./scripts/new-host-template.sh \
  --platform nixos \
  --hostname my-laptop \
  --username myuser \
  --fullname "My Name" \
  --arch x86_64-linux \
  --rust true \
  --nodejs true
  # ... (see bootstrap.sh for all options)
```

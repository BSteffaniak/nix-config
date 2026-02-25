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
│
├── hosts/                   # Per-machine configurations
│   ├── nixos-desktop/      # NixOS desktop PC
│   ├── macbook-air/        # MacBook Air (Apple Silicon)
│   └── mac-studio/         # Mac Studio
│
├── modules/                 # Reusable modules
│   ├── common/             # Cross-platform modules
│   │   ├── development/    # Dev tools (rust, node, go, python, etc.)
│   │   ├── shell/          # Shell configuration (fish, git)
│   │   ├── editors/        # Text editors (neovim)
│   │   └── cli-tools/      # CLI utilities (tmux, fzf, ripgrep, etc.)
│   │
│   ├── nixos/              # NixOS-specific modules
│   │   ├── boot/           # Boot configuration
│   │   ├── hardware/       # Hardware support (nvidia, graphics)
│   │   ├── desktop/        # Desktop environment (hyprland, waybar, gtk)
│   │   ├── services/       # System services (docker, observability, minecraft)
│   │   └── system/         # System configuration (networking, security, audio)
│   │
│   └── darwin/             # macOS-specific modules
│       ├── homebrew.nix    # Homebrew integration
│       ├── system-defaults.nix  # macOS system preferences
│       └── applications.nix     # Application management
│
├── home/                    # Home Manager configurations
│   ├── common/             # Cross-platform home config
│   ├── nixos/              # NixOS-specific home config
│   └── darwin/             # macOS-specific home config
│
└── lib/                     # Helper functions
    └── default.nix
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
- `ra-multiplex` - Rust Analyzer multiplexer
- `fuzzel` - Fuzzel application launcher
- `waypaper` - Waypaper wallpaper manager
- `act` - GitHub Actions locally
- `htop` - htop system monitor

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

### Standalone Home Manager (Ubuntu, etc.)

- **ubuntu-laptop**: Ubuntu laptop with home-manager only (see [UBUNTU-SETUP.md](UBUNTU-SETUP.md))

## Using on Ubuntu or Other Linux Distros

This configuration can be used on Ubuntu or any Linux distro via standalone home-manager!

**Quick start:**

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Clone this repo
git clone <your-repo-url> ~/.config/nixos

# Apply the configuration
nix run home-manager/release-25.05 -- switch --flake ~/.config/nixos#braden@ubuntu-laptop
```

See [UBUNTU-SETUP.md](UBUNTU-SETUP.md) for detailed Ubuntu setup instructions.

**What you get:**

- All development tools (Rust, Node.js, Go, Python, etc.)
- Rootless Podman for containers (Docker-compatible!)
- DevOps tools (kubectl, helm, terraform, aws-cli)
- Complete shell setup (fish, git, ssh, neovim)
- All CLI utilities
- No sudo required for package management!

## Customization

Each host can enable/disable features via the `myConfig` options in `hosts/*/default.nix`:

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

Currently managed packages: `cronstrue` (npm), `ra-multiplex` (Rust), `zellij` (Rust).

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

Understanding where to add packages based on their purpose and scope:

### Cross-Platform Packages (All Hosts)

**System-Level CLI Tools:**

- **Location:** `modules/common/cli-tools/default.nix`
- **Use for:** Command-line utilities, system tools (tmux, fzf, ripgrep, htop, etc.)
- **Example:**
  ```nix
  environment.systemPackages = with pkgs; [
    # ... existing packages
    yq  # Add new CLI tool here
  ];
  ```

**Development Tools:**

- **Location:** `modules/common/development/` (language-specific files)
- **Use for:** Programming language toolchains, build tools, linters
- **Example:** Add to `devops.nix` for infrastructure tools, or create new module
  ```nix
  # modules/common/development/devops.nix
  environment.systemPackages = with pkgs; [
    # ... existing packages
    terraform  # Add new devops tool
  ];
  ```

**User Applications (GUI/Desktop):**

- **Location:** `home/common/packages.nix`
- **Use for:** Personal applications, GUI tools, user-specific packages
- **Scope:** Installed for your user across all platforms
- **Example:**
  ```nix
  home.packages = with pkgs; [
    # ... existing packages
    spotify  # Add desktop app
  ];
  ```

### Platform-Specific Packages

**NixOS Only:**

- **Location:** Appropriate module in `modules/nixos/*/`
  - Desktop apps: `modules/nixos/desktop/*.nix`
  - System services: `modules/nixos/services/*.nix`
- **Example:**
  ```nix
  # modules/nixos/desktop/hyprland.nix
  environment.systemPackages = with pkgs; [
    # ... existing packages
    waybar-experimental  # Add Wayland-specific tool
  ];
  ```

**Darwin (macOS) Only:**

- **Location:** `modules/darwin/*.nix` or `home/darwin/default.nix`
- **Example:**
  ```nix
  # home/darwin/default.nix
  home.packages = with pkgs; [
    # ... existing packages
    rectangle  # Add macOS-specific app
  ];
  ```

**Single Host Only:**

- **Location:** `hosts/<hostname>/default.nix`
- **Use for:** Machine-specific packages (testing, hardware-specific tools)
- **Example:**
  ```nix
  # hosts/nixos-desktop/default.nix
  environment.systemPackages = with pkgs; [
    inputs.home-manager.packages."${pkgs.system}".default
    specialized-tool  # Only on this machine
  ];
  ```

### Quick Decision Guide

| I want to add...                    | Where?                                      |
| ----------------------------------- | ------------------------------------------- |
| CLI tool for all machines           | `modules/common/cli-tools/default.nix`      |
| Language toolchain (rust, go, etc.) | `modules/common/development/<language>.nix` |
| Desktop app for me (all platforms)  | `home/common/packages.nix`                  |
| NixOS desktop tool                  | `modules/nixos/desktop/*.nix`               |
| macOS-specific app                  | `home/darwin/default.nix`                   |
| Testing on one machine only         | `hosts/<hostname>/default.nix`              |

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
- Generate a complete host configuration in `hosts/<hostname>/default.nix`
- For NixOS: copy or generate `hardware-configuration.nix`
- Provide instructions for updating the appropriate flake
- Update `rebuild.sh` to recognize the new hostname

The bootstrap script asks about:

- **Development tools**: Rust, Node.js, Go, Python, Java, Zig, Android SDK, DevOps tools
- **Desktop environment** (NixOS only): Hyprland, Waybar, GTK, X Server
- **Hardware support** (NixOS only): NVIDIA GPU, graphics, audio
- **System services**: Docker, Podman, Minecraft server, observability
- **Shell & editors**: Fish shell, Neovim (with optional nightly builds), Git config

### Hardware Detection (NixOS)

Before bootstrapping a NixOS host, you can run the hardware detection script:

```bash
./scripts/detect-hardware.sh
```

This will detect your CPU, GPU, audio, network hardware, and provide configuration suggestions.

### Manual Setup

If you prefer to set up a host manually:

1. Create a new directory in `hosts/` (e.g., `hosts/new-laptop/`)
2. Create `hosts/new-laptop/default.nix` based on existing examples
3. Add the host to the root `flake.nix`:
   - For NixOS: Add to `nixosConfigurations` section
   - For Darwin: Add to `darwinConfigurations` section
   - For Standalone: Add to `homeConfigurations` section
4. Update `rebuild.sh` to recognize the new hostname

## Module System

All modules use NixOS module system options for configurability:

- **Common modules**: Available on all platforms
- **NixOS modules**: Linux-specific features
- **Darwin modules**: macOS-specific features

This allows sharing development tools, shell configurations, and CLI utilities across all machines while keeping platform-specific features separate.

### System vs User Packages

- **System packages** (`environment.systemPackages`): Available to all users, included in system PATH
- **User packages** (`home.packages`): Installed per-user via Home Manager, in user profile
- **Rule of thumb**: System services/tools → system packages; personal apps → user packages

## Home Manager Configuration

Home Manager configurations are organized to be generic and reusable across hosts:

```
home/
├── common/              # Shared cross-platform user config
│   ├── git.nix         # Git configuration
│   ├── shell.nix       # Shell setup
│   └── packages.nix    # User packages
├── modules/            # Optional home-manager modules
│   └── gtk-theming.nix # GTK theming (opt-in)
├── nixos/
│   └── default.nix     # Generic NixOS home config
└── darwin/
    └── default.nix     # Generic Darwin home config
```

### Key Principles

**Generic Base Configs:**

- `home/nixos/default.nix` and `home/darwin/default.nix` are generic templates
- They dynamically read username and settings from host configuration
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

Then import it in your flake:

```nix
# nixos/flake.nix
home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  users.braden = {
    imports = [
      ../home/nixos          # Generic base config
      ../hosts/nixos-desktop/home.nix  # Personal overrides
    ];
  };
  extraSpecialArgs = {
    inherit inputs;
    osConfig = config;  # Pass system config to home-manager
  };
};
```

**Important:** Always pass `osConfig = config` in `extraSpecialArgs` so home-manager can read username and state version from the system configuration.

## Updating

**All Platforms (Unified Flake):**

```bash
# Update all inputs (affects all platforms)
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs          # NixOS packages
nix flake lock --update-input nixpkgs-darwin  # macOS packages
nix flake lock --update-input rust-overlay    # Rust toolchain

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

# Bootstrap Scripts

Helper scripts for creating and managing NixOS/Darwin host configurations.

## Scripts Overview

### `bootstrap.sh` (Main Script)

Interactive bootstrap script that guides you through creating a new host configuration.

**Features:**

- Auto-detects platform (NixOS/Darwin) and architecture
- Interactive prompts for all configuration options
- Generates complete host configuration (`meta.nix`, `default.nix`, `home.nix`)
- Handles hardware-configuration.nix for NixOS
- Auto-discovered by flake and `rebuild.sh` (no manual edits needed)
- Optional git commit

**Usage:**

```bash
./bootstrap.sh
```

The script will prompt you for:

1. Platform selection (NixOS or Darwin)
2. Architecture (x86_64, aarch64)
3. Hostname and user information
4. Development tools (Rust, Node.js, Go, Python, Java, Zig, Android, DevOps)
5. Editors and shell (Neovim, Fish, Git config, CLI tools)
6. Platform-specific options:
   - **NixOS**: Desktop environment, hardware support, services
   - **Darwin**: Homebrew, system defaults, applications
7. State version

### `new-host-template.sh` (Template Generator)

Generates host configuration files from command-line arguments. Called by `bootstrap.sh` but can be used standalone.

**Usage:**

```bash
./scripts/new-host-template.sh \
  --platform nixos \
  --hostname my-laptop \
  --username myuser \
  --fullname "My Name" \
  --arch x86_64-linux \
  --rust true \
  --nodejs true \
  --go true \
  --state-version 24.11
```

**Available Options:**

Platform options:

- `--platform` - "nixos" or "darwin"
- `--hostname` - Host name
- `--username` - Primary user
- `--fullname` - Full name
- `--arch` - Architecture (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin)
- `--state-version` - NixOS/Darwin state version

Development tools:

- `--rust`, `--nodejs`, `--go`, `--python`, `--java`, `--zig` - true/false
- `--android`, `--devops`, `--openssl` - true/false
- `--podman` (Darwin), `--docker` (NixOS) - true/false

Editors and shell:

- `--neovim`, `--neovim-nightly` - true/false
- `--fish`, `--git`, `--clitools` - true/false

NixOS-specific:

- `--desktop`, `--hyprland`, `--waybar`, `--gtk`, `--xserver` - true/false
- `--nvidia`, `--graphics` - true/false
- `--boot`, `--latest-kernel` - true/false
- `--system`, `--networking`, `--ssh`, `--security`, `--audio`, `--locale` - true/false
- `--timezone` - Timezone string
- `--docker-data-root` - Docker data directory
- `--observability`, `--minecraft`, `--nixos-clitools` - true/false

Darwin-specific:

- `--homebrew`, `--system-defaults`, `--applications` - true/false
- `--computer-name` - Display name for the computer

### `source-build.sh` (Source Build Hash Manager)

Manages dependency hashes (`npmDepsHash`, `cargoHash`) for source-built Nix packages. Eliminates the need to manually update hashes when flake inputs change.

**The problem it solves:** When you run `nix flake update cronstrue` and the upstream `package-lock.json` or `Cargo.lock` changed, the hardcoded hash in the overlay becomes stale and the build breaks. This script automates hash computation so you never have to manually copy hashes from error messages.

**Safety feature:** Each overlay validates the git rev at Nix evaluation time. If you run `nix flake update` and forget to update hashes, you get a clear error:

```
error: cronstrue: hash file is stale.
  flake.lock rev: abc1234
  hash file rev:  def5678
Run: ./scripts/source-build.sh update cronstrue
```

**Usage:**

```bash
# Interactive main menu
./scripts/source-build.sh

# Subcommands
./scripts/source-build.sh update                  # Interactive: pick packages
./scripts/source-build.sh update --all            # Non-interactive: update all
./scripts/source-build.sh update cronstrue        # Non-interactive: update one
./scripts/source-build.sh list                    # List packages + stale status
./scripts/source-build.sh check                   # Check for stale hashes (dry run)
./scripts/source-build.sh add                     # Interactive wizard
./scripts/source-build.sh remove                  # Interactive remove
./scripts/source-build.sh remove <name>           # Non-interactive remove
```

**Supported build systems:**

- **npm** (`npmDepsHash`): Uses `prefetch-npm-deps` for fast, single-download hash computation
- **Rust** (`cargoHash`): Uses `fetchCargoVendoredDeps` with automatic hash extraction. Downloads cargo dependencies once; they're cached for the real build

**Auto-discovery:** Simple source-built packages (Rust `buildRustPackage` with no custom build steps) are **automatically discovered** from `lib/source-builds/configs/*.json`. No manual Nix file edits are needed — just create a config JSON, compute the hash, and the package appears in `pkgs`.

**Adding a new simple source-built package:**

```bash
# 1. Add flake input to flake.nix (the only Nix file edit needed)
#    my-tool-src = { url = "github:someone/my-tool"; flake = false; };

# 2. Create config JSON
cat > lib/source-builds/configs/my-tool.json << 'EOF'
{
    "flakeInput": "my-tool-src",
    "buildSystem": "rust",
    "pname": "my-tool",
    "hashField": "cargoHash"
}
EOF

# 3. Lock the input and compute hash
nix flake lock
./scripts/source-build.sh update my-tool

# 4. Use pkgs.my-tool in your host config — done!
```

**Config JSON fields:**

| Field             | Required | Description                                                                  |
| ----------------- | -------- | ---------------------------------------------------------------------------- |
| `flakeInput`      | Yes      | Name of the flake input in `flake.nix`                                       |
| `buildSystem`     | Yes      | `"rust"` or `"npm"`                                                          |
| `pname`           | Yes      | Package attribute name in `pkgs`                                             |
| `hashField`       | Yes      | `"cargoHash"` or `"npmDepsHash"`                                             |
| `doCheck`         | No       | Run tests? Default: `true`                                                   |
| `cargoBuildFlags` | No       | Array of extra cargo flags, e.g. `["--package", "my-bin"]`                   |
| `cargoLockFile`   | No       | Path to repo-managed lockfile for repos without `Cargo.lock`                 |
| `complex`         | No       | Set to `true` to skip auto-discovery (use a standalone overlay file instead) |

**Complex builds:** Packages that need custom toolchains, build phases, `nativeBuildInputs`, etc. should set `"complex": true` in their config and use a standalone overlay file in `lib/overlays/`. See `lib/overlays/zellij.nix` and `lib/overlays/cronstrue.nix` for examples.

**Directory structure:**

```
lib/source-builds/
  configs/              # Per-package config (committed)
    my-tool.json        # { flakeInput, buildSystem, pname, hashField, ... }
    zellij.json         # { ..., "complex": true } — uses standalone overlay
  hashes/               # Auto-generated hash data (committed)
    my-tool.json        # { rev, cargoHash }
    zellij.json         # { rev, cargoHash }
```

**Important:** The `hashes/` directory contains pinned dependency hashes that Nix reads at evaluation time. These files must be committed to git so all machines use the same hashes.

For Rust repos that do not commit a `Cargo.lock`, set `cargoLockFile` in the package config and point it to a lock file in this repo (for example `lib/source-builds/locks/<name>-Cargo.lock`).

**Typical workflow after updating flake inputs:**

```bash
nix flake update                           # Update all flake inputs
./scripts/source-build.sh check            # See what's stale
./scripts/source-build.sh update --all     # Fix all stale hashes
# Commit the updated hashes/ files
```

**Network cost:** Dependencies are downloaded exactly once during hash computation. The subsequent Nix build finds them cached in the store. No double-downloads.

### `clean.sh` (Nix Store Cleanup Helper)

Runs common Nix cleanup commands so you do not need to remember them.

**What it does:**

- Cleans old user generations with `nix-collect-garbage`
- Optionally cleans system generations with `sudo nix-collect-garbage`
- Optionally optimizes the store with `sudo nix-store --optimise`

**Default behavior:**

- Deletes generations older than `14d`
- Runs both user and system cleanup (if `sudo` is available)

**Usage:**

```bash
./scripts/clean.sh
./scripts/clean.sh --older-than 30d
./scripts/clean.sh --delete-all-old
./scripts/clean.sh --delete-all-old --no-sudo
```

**Options:**

- `-o, --older-than <duration>` - Delete generations older than a duration (default: `14d`)
- `-d, --delete-all-old` - Aggressive cleanup (equivalent to `nix-collect-garbage -d`)
- `--no-sudo` - Skip system cleanup and store optimization
- `-y, --yes` - Skip confirmation prompt
- `-h, --help` - Show help text

### `update-all.sh` (Unified Update Helper)

Runs all update steps in one command so you do not need to remember each script.

**Default order:**

1. `nix flake update`
2. `./scripts/source-build.sh update --all`
3. `./scripts/github-release.sh update --all`

If any step fails, the script exits immediately so you can fix the issue before continuing.

**Usage:**

```bash
./scripts/update-all.sh
./scripts/update-all.sh --yes
./scripts/update-all.sh --no-github
```

**Options:**

- `--no-flake` - Skip flake input updates
- `--no-source` - Skip source-build hash updates
- `--no-github` - Skip GitHub release updates
- `-y, --yes` - Skip confirmation prompt
- `-h, --help` - Show help text

At the end it prints `git status --short` so you can immediately see what changed.

### `detect-hardware.sh` (Hardware Detection)

NixOS-only script that detects hardware and suggests appropriate configuration options.

**Features:**

- Detects CPU (AMD/Intel) and suggests microcode updates
- Detects GPU (NVIDIA/AMD/Intel) and suggests drivers
- Detects audio hardware
- Detects network interfaces and WiFi
- Detects Bluetooth
- Detects storage type (NVMe, SSD)
- Detects virtualization (KVM, VMware, VirtualBox)
- Detects laptop touchpad
- Provides configuration snippet suggestions

**Usage:**

```bash
./scripts/detect-hardware.sh
```

Run this before bootstrapping a NixOS host to get hardware-specific recommendations.

### `github-release.sh` (GitHub Release Manager)

Manages pre-built binary packages from GitHub releases. Supports both interactive and non-interactive modes.

This script handles the full lifecycle: adding new projects, updating versions, listing status, and removing projects. It works with the auto-discovery overlay system in `lib/overlays/github-releases.nix` — adding a new project only requires creating a config JSON file (no Nix file edits).

**Usage:**

```bash
# Interactive main menu
./scripts/github-release.sh

# Subcommands
./scripts/github-release.sh update                    # Interactive: pick projects to update
./scripts/github-release.sh update --all              # Non-interactive: update all
./scripts/github-release.sh update opencode           # Non-interactive: update one
./scripts/github-release.sh add                       # Interactive: wizard to add new project
./scripts/github-release.sh add --non-interactive \   # Non-interactive: create from args
    --owner org --repo tool --pname tool-dev
./scripts/github-release.sh remove                    # Interactive: pick project to remove
./scripts/github-release.sh remove some-tool          # Non-interactive: remove by name
./scripts/github-release.sh list                      # List all configured projects
./scripts/github-release.sh check                     # Check all for updates (dry run)
```

**Interactive `add` wizard:**

1. Prompts for GitHub `owner/repo`
2. Fetches the latest release and displays available assets
3. Prompts for Nix package name, binary name, installed binary name
4. Auto-detects version prefix stripping (e.g., `v` from `v1.2.3`)
5. Auto-detects platform-to-asset mapping from asset filenames (linux/darwin, x64/arm64)
6. Prompts for license and description
7. Writes the config JSON and fetches version data automatically

**Non-interactive `add`:**

```bash
./scripts/github-release.sh add --non-interactive \
    --owner junegunn \
    --repo fzf \
    --pname fzf-bleeding \
    --binary-name fzf \
    --installed-binary-name fzf-bleeding \
    --strip-prefix v \
    --license mit \
    --description "Fuzzy finder (latest from GitHub releases)"
```

Platform asset names can be specified explicitly or auto-detected:

```bash
# Explicit platform mapping
./scripts/github-release.sh add --non-interactive \
    --owner user --repo tool --pname tool-dev \
    --x86_64-linux "tool-linux-amd64.tar.gz" \
    --aarch64-darwin "tool-darwin-arm64.zip"

# Or omit platform flags for auto-detection from release assets
./scripts/github-release.sh add --non-interactive \
    --owner user --repo tool --pname tool-dev
```

**Directory structure:**

```
lib/github-releases/
  configs/           # Per-project config (written once, committed)
    opencode.json    # Repo, asset mapping, binary names, metadata
  versions/          # Auto-generated version data (committed)
    opencode.json    # URLs, sha256 hashes, version number
  mkGitHubRelease.nix  # Shared Nix builder function
```

**Important:** The `versions/` directory contains pinned version data that Nix reads at evaluation time. These files must be committed to git so that all machines see the same versions.

**Hash resolution:** The script uses the GitHub API `digest` field (sha256) when available for fast hash lookups. Falls back to `nix-prefetch-url` for repos that don't provide digests.

## Workflow Examples

### New NixOS Desktop

```bash
# 1. Detect hardware (optional but recommended)
./scripts/detect-hardware.sh

# 2. Run bootstrap
./bootstrap.sh
# - Select NixOS
# - Enable desktop, Hyprland, etc.
# - Enable NVIDIA if detected
# - Enable development tools as needed

# 3. Test and apply (host is auto-discovered from meta.nix)
sudo nixos-rebuild build --flake .#new-hostname
./rebuild.sh
```

### New Darwin (macOS) Laptop

```bash
# 1. Run bootstrap
./bootstrap.sh
# - Select Darwin
# - Choose architecture (Apple Silicon vs Intel)
# - Enable development tools
# - Enable Homebrew and system defaults

# 2. Test and apply (host is auto-discovered from meta.nix)
darwin-rebuild build --flake .#new-hostname
./rebuild.sh
```

### Programmatic Host Creation

```bash
# Create a minimal server configuration
./scripts/new-host-template.sh \
  --platform nixos \
  --hostname server-01 \
  --username admin \
  --fullname "Admin User" \
  --arch x86_64-linux \
  --rust false \
  --nodejs false \
  --go true \
  --desktop false \
  --boot true \
  --networking true \
  --ssh true \
  --docker true \
  --state-version 24.11

# The host is auto-discovered from meta.nix -- no flake or rebuild.sh edits needed
```

## Notes

- Hosts are **auto-discovered** from `hosts/*/meta.nix`. No manual edits to `flake.nix` or `rebuild.sh` are needed when adding a new host.
- For NixOS, make sure to generate or copy `hardware-configuration.nix` - the bootstrap script will help with this.
- Always test your configuration with `build` before applying with `switch`.
- The scripts preserve your existing hosts and configurations - they only add new ones.
- State versions should match your NixOS/Darwin release version at the time of first install.

## Troubleshooting

**"nixos-generate-config not found"**

- This command is only available on NixOS systems
- If bootstrapping from another system, you'll need to copy hardware-configuration.nix manually after installation

**"Configuration build failed"**

- Check that `hosts/<name>/meta.nix` exists and has correct `type`, `system`, `hostname`, and `username` values
- Verify all referenced modules exist
- Check syntax of generated configuration

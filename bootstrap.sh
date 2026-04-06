#!/usr/bin/env bash

# Bootstrap script for creating new NixOS/Darwin host configurations
# This script interactively sets up a new host configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local result

    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " result
        result="${result:-y}"
    else
        read -p "$prompt [y/N]: " result
        result="${result:-n}"
    fi

    [[ "$result" =~ ^[Yy] ]]
}

# Detect platform
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [[ "$ID" == "nixos" ]]; then
                echo "nixos"
            else
                echo "linux"
            fi
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# Detect architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "x86_64"
            ;;
        arm64|aarch64)
            echo "aarch64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Main bootstrap process
print_header "NixOS/Darwin Host Bootstrap"

echo "This script will help you create a new host configuration."
echo "It will generate the necessary files. The flake and rebuild script"
echo "auto-discover hosts from hosts/*/meta.nix -- no manual edits needed."
echo ""

# Step 1: Platform Selection
print_header "Step 1: Platform Selection"

DETECTED_PLATFORM=$(detect_platform)
echo "Detected platform: $DETECTED_PLATFORM"

if [ "$DETECTED_PLATFORM" = "unknown" ]; then
    print_error "Unable to detect platform automatically."
    echo "Please choose:"
    echo "  1) NixOS (Linux)"
    echo "  2) Darwin (macOS)"
    read -p "Selection [1-2]: " platform_choice
    case $platform_choice in
        1) PLATFORM="nixos" ;;
        2) PLATFORM="darwin" ;;
        *) print_error "Invalid selection"; exit 1 ;;
    esac
else
    PLATFORM="$DETECTED_PLATFORM"
    if prompt_yes_no "Use detected platform ($PLATFORM)?" "y"; then
        : # Keep detected platform
    else
        echo "Please choose:"
        echo "  1) NixOS (Linux)"
        echo "  2) Darwin (macOS)"
        read -p "Selection [1-2]: " platform_choice
        case $platform_choice in
            1) PLATFORM="nixos" ;;
            2) PLATFORM="darwin" ;;
            *) print_error "Invalid selection"; exit 1 ;;
        esac
    fi
fi

print_success "Platform: $PLATFORM"

# Step 2: Architecture Selection
print_header "Step 2: Architecture"

DETECTED_ARCH=$(detect_arch)
echo "Detected architecture: $DETECTED_ARCH"

if [ "$PLATFORM" = "darwin" ]; then
    echo "Please select architecture:"
    echo "  1) aarch64-darwin (Apple Silicon M1/M2/M3)"
    echo "  2) x86_64-darwin (Intel Mac)"
    
    if [ "$DETECTED_ARCH" = "aarch64" ]; then
        ARCH_DEFAULT="1"
    else
        ARCH_DEFAULT="2"
    fi
    
    read -p "Selection [1-2] [$ARCH_DEFAULT]: " arch_choice
    arch_choice="${arch_choice:-$ARCH_DEFAULT}"
    
    case $arch_choice in
        1) ARCH="aarch64-darwin" ;;
        2) ARCH="x86_64-darwin" ;;
        *) print_error "Invalid selection"; exit 1 ;;
    esac
else
    # NixOS
    ARCH="x86_64-linux"
    if [ "$DETECTED_ARCH" = "aarch64" ]; then
        if prompt_yes_no "Use ARM64 architecture?" "y"; then
            ARCH="aarch64-linux"
        fi
    fi
fi

print_success "Architecture: $ARCH"

# Step 3: Hostname
print_header "Step 3: Hostname"

CURRENT_HOSTNAME=$(hostname)
HOSTNAME=$(prompt_input "Enter hostname for this configuration" "$CURRENT_HOSTNAME")

# Check if hostname already exists
if [ -d "$SCRIPT_DIR/hosts/$HOSTNAME" ]; then
    print_error "Host '$HOSTNAME' already exists!"
    if ! prompt_yes_no "Overwrite existing configuration?" "n"; then
        print_error "Aborting."
        exit 1
    fi
fi

print_success "Hostname: $HOSTNAME"

# Step 4: User Information
print_header "Step 4: User Information"

CURRENT_USER=$(whoami)
USERNAME=$(prompt_input "Enter username" "$CURRENT_USER")
FULL_NAME=$(prompt_input "Enter full name" "")

print_success "Username: $USERNAME"
print_success "Full name: $FULL_NAME"

# Step 5: Development Tools
print_header "Step 5: Development Tools"

echo "Select development tools to enable (y/n for each):"
ENABLE_RUST=$(prompt_yes_no "  Rust toolchain?" "y" && echo "true" || echo "false")
ENABLE_NODEJS=$(prompt_yes_no "  Node.js?" "y" && echo "true" || echo "false")
ENABLE_GO=$(prompt_yes_no "  Go?" "y" && echo "true" || echo "false")
ENABLE_PYTHON=$(prompt_yes_no "  Python?" "n" && echo "true" || echo "false")
ENABLE_JAVA=$(prompt_yes_no "  Java?" "n" && echo "true" || echo "false")
ENABLE_ZIG=$(prompt_yes_no "  Zig?" "n" && echo "true" || echo "false")
ENABLE_ANDROID=$(prompt_yes_no "  Android SDK?" "n" && echo "true" || echo "false")
ENABLE_DEVOPS=$(prompt_yes_no "  DevOps tools (terraform, kubectl, etc)?" "y" && echo "true" || echo "false")
ENABLE_OPENSSL=$(prompt_yes_no "  OpenSSL development?" "y" && echo "true" || echo "false")

# .NET Configuration
ENABLE_DOTNET=$(prompt_yes_no "  .NET SDK?" "n" && echo "true" || echo "false")
if [ "$ENABLE_DOTNET" = "true" ]; then
    DOTNET_RUNTIME_ONLY=$(prompt_yes_no "    Runtime-only (no SDK)?" "n" && echo "true" || echo "false")

    if [ "$DOTNET_RUNTIME_ONLY" = "true" ]; then
        echo "    Select .NET runtime versions (separate with spaces, or leave empty for latest):"
        echo "      Available: 6, 7, 8, 9, 10"
        read -p "    Versions: " DOTNET_RUNTIME_VERSIONS
    else
        echo "    Select .NET SDK versions (separate with spaces, or leave empty for latest):"
        echo "      Available: 6, 7, 8, 9, 10"
        read -p "    Versions: " DOTNET_SDK_VERSIONS
    fi

    ENABLE_ASPNETCORE=$(prompt_yes_no "    Enable ASP.NET Core runtime?" "n" && echo "true" || echo "false")
    if [ "$ENABLE_ASPNETCORE" = "true" ]; then
        echo "    Select ASP.NET Core versions (separate with spaces, or leave empty for latest):"
        echo "      Available: 8, 9, 10"
        read -p "    Versions: " ASPNETCORE_VERSIONS
    fi

    ENABLE_EF=$(prompt_yes_no "    Enable Entity Framework tools?" "y" && echo "true" || echo "false")

    echo "    Global .NET tools:"
    ENABLE_DOTNET_OUTDATED=$(prompt_yes_no "      dotnet-outdated (check outdated dependencies)?" "n" && echo "true" || echo "false")
    ENABLE_DOTNET_REPL=$(prompt_yes_no "      dotnet-repl (interactive C# REPL)?" "n" && echo "true" || echo "false")
    ENABLE_DOTNET_FORMATTERS=$(prompt_yes_no "      Code formatters (CSharpier, Fantomas)?" "n" && echo "true" || echo "false")
    ENABLE_DOTNET_PAKET=$(prompt_yes_no "      Paket (dependency manager)?" "n" && echo "true" || echo "false")

    ENABLE_NUGET_CUSTOM=$(prompt_yes_no "    Configure custom NuGet sources?" "n" && echo "true" || echo "false")
    if [ "$ENABLE_NUGET_CUSTOM" = "true" ]; then
        echo "    Enter custom NuGet sources (one per line, format: name=url)"
        echo "    Press Enter on empty line when done:"
        NUGET_SOURCES=""
        while true; do
            read -p "    Source: " nuget_source
            if [ -z "$nuget_source" ]; then
                break
            fi
            NUGET_SOURCES="$NUGET_SOURCES$nuget_source|"
        done
    fi
else
    DOTNET_RUNTIME_ONLY="false"
    DOTNET_SDK_VERSIONS=""
    DOTNET_RUNTIME_VERSIONS=""
    ENABLE_ASPNETCORE="false"
    ASPNETCORE_VERSIONS=""
    ENABLE_EF="false"
    ENABLE_DOTNET_OUTDATED="false"
    ENABLE_DOTNET_REPL="false"
    ENABLE_DOTNET_FORMATTERS="false"
    ENABLE_DOTNET_PAKET="false"
    ENABLE_NUGET_CUSTOM="false"
    NUGET_SOURCES=""
fi

# Platform-specific tools
if [ "$PLATFORM" = "darwin" ]; then
    ENABLE_PODMAN=$(prompt_yes_no "  Podman (container runtime)?" "y" && echo "true" || echo "false")
    ENABLE_DOCKER="false"
else
    ENABLE_PODMAN="false"
    ENABLE_DOCKER=$(prompt_yes_no "  Docker?" "y" && echo "true" || echo "false")
fi

# Step 6: Editors and Shell
print_header "Step 6: Editors and Shell"

ENABLE_NEOVIM=$(prompt_yes_no "Enable Neovim?" "y" && echo "true" || echo "false")
if [ "$ENABLE_NEOVIM" = "true" ]; then
    NEOVIM_NIGHTLY=$(prompt_yes_no "  Use Neovim nightly?" "y" && echo "true" || echo "false")
else
    NEOVIM_NIGHTLY="false"
fi

ENABLE_FISH=$(prompt_yes_no "Enable Fish shell?" "y" && echo "true" || echo "false")
ENABLE_BASH=$(prompt_yes_no "Enable Bash shell?" "y" && echo "true" || echo "false")
ENABLE_ZSH=$(prompt_yes_no "Enable Zsh shell?" "y" && echo "true" || echo "false")
ENABLE_NUSHELL=$(prompt_yes_no "Enable Nushell?" "y" && echo "true" || echo "false")

DEFAULT_SHELL=$(prompt_input "Default shell (fish/bash/zsh/nushell)" "fish")
case "$DEFAULT_SHELL" in
    fish|bash|zsh|nushell) ;;
    *)
        print_warning "Invalid default shell '$DEFAULT_SHELL', falling back to fish"
        DEFAULT_SHELL="fish"
        ;;
esac

# Ensure the selected default shell is enabled
if [ "$DEFAULT_SHELL" = "fish" ] && [ "$ENABLE_FISH" != "true" ]; then
    ENABLE_FISH="true"
fi
if [ "$DEFAULT_SHELL" = "bash" ] && [ "$ENABLE_BASH" != "true" ]; then
    ENABLE_BASH="true"
fi
if [ "$DEFAULT_SHELL" = "zsh" ] && [ "$ENABLE_ZSH" != "true" ]; then
    ENABLE_ZSH="true"
fi
if [ "$DEFAULT_SHELL" = "nushell" ] && [ "$ENABLE_NUSHELL" != "true" ]; then
    ENABLE_NUSHELL="true"
fi

ENABLE_GIT=$(prompt_yes_no "Enable Git configuration?" "y" && echo "true" || echo "false")
ENABLE_CLITOOLS=$(prompt_yes_no "Enable CLI tools (tmux, fzf, ripgrep, etc)?" "y" && echo "true" || echo "false")

# Step 7: Platform-specific Configuration
if [ "$PLATFORM" = "nixos" ]; then
    print_header "Step 7: NixOS-Specific Configuration"
    
    # Desktop Environment
    ENABLE_DESKTOP=$(prompt_yes_no "Enable desktop environment?" "y" && echo "true" || echo "false")
    
    if [ "$ENABLE_DESKTOP" = "true" ]; then
        ENABLE_HYPRLAND=$(prompt_yes_no "  Enable Hyprland (Wayland compositor)?" "y" && echo "true" || echo "false")
        ENABLE_WAYBAR=$(prompt_yes_no "  Enable Waybar?" "y" && echo "true" || echo "false")
        ENABLE_GTK=$(prompt_yes_no "  Enable GTK theming?" "y" && echo "true" || echo "false")
        ENABLE_XSERVER=$(prompt_yes_no "  Enable X Server?" "y" && echo "true" || echo "false")
    else
        ENABLE_HYPRLAND="false"
        ENABLE_WAYBAR="false"
        ENABLE_GTK="false"
        ENABLE_XSERVER="false"
    fi
    
    # Hardware
    print_header "Hardware Configuration"
    ENABLE_NVIDIA=$(prompt_yes_no "Enable NVIDIA GPU support?" "n" && echo "true" || echo "false")
    ENABLE_GRAPHICS=$(prompt_yes_no "Enable graphics/OpenGL support?" "y" && echo "true" || echo "false")
    
    # Boot
    ENABLE_BOOT=$(prompt_yes_no "Enable boot configuration?" "y" && echo "true" || echo "false")
    if [ "$ENABLE_BOOT" = "true" ]; then
        USE_LATEST_KERNEL=$(prompt_yes_no "  Use latest kernel?" "n" && echo "true" || echo "false")
    else
        USE_LATEST_KERNEL="false"
    fi
    
    # System
    ENABLE_SYSTEM=$(prompt_yes_no "Enable system configuration (networking, security, audio)?" "y" && echo "true" || echo "false")
    
    if [ "$ENABLE_SYSTEM" = "true" ]; then
        ENABLE_NETWORKING=$(prompt_yes_no "  Enable networking?" "y" && echo "true" || echo "false")
        if [ "$ENABLE_NETWORKING" = "true" ]; then
            ENABLE_SSH=$(prompt_yes_no "    Enable SSH server?" "y" && echo "true" || echo "false")
        else
            ENABLE_SSH="false"
        fi
        ENABLE_SECURITY=$(prompt_yes_no "  Enable security settings?" "y" && echo "true" || echo "false")
        ENABLE_AUDIO=$(prompt_yes_no "  Enable audio (PipeWire)?" "y" && echo "true" || echo "false")
        ENABLE_LOCALE=$(prompt_yes_no "  Enable locale settings?" "y" && echo "true" || echo "false")
        
        if [ "$ENABLE_LOCALE" = "true" ]; then
            TIMEZONE=$(prompt_input "    Timezone" "America/New_York")
        else
            TIMEZONE="America/New_York"
        fi
    else
        ENABLE_NETWORKING="false"
        ENABLE_SSH="false"
        ENABLE_SECURITY="false"
        ENABLE_AUDIO="false"
        ENABLE_LOCALE="false"
        TIMEZONE="America/New_York"
    fi
    
    # Services
    print_header "Services"
    DOCKER_DATA_ROOT=""
    if [ "$ENABLE_DOCKER" = "true" ]; then
        DOCKER_DATA_ROOT=$(prompt_input "  Docker data root directory (leave empty for default)" "")
    fi
    
    ENABLE_OBSERVABILITY=$(prompt_yes_no "Enable observability (monitoring)?" "n" && echo "true" || echo "false")
    ENABLE_MINECRAFT=$(prompt_yes_no "Enable Minecraft server?" "n" && echo "true" || echo "false")
    ENABLE_NIXOS_CLITOOLS=$(prompt_yes_no "Enable NixOS-specific CLI tools?" "y" && echo "true" || echo "false")
    
    # State version
    STATE_VERSION=$(prompt_input "NixOS state version" "24.11")
    
elif [ "$PLATFORM" = "darwin" ]; then
    print_header "Step 7: Darwin-Specific Configuration"
    
    ENABLE_HOMEBREW=$(prompt_yes_no "Enable Homebrew integration?" "y" && echo "true" || echo "false")
    ENABLE_SYSTEM_DEFAULTS=$(prompt_yes_no "Enable macOS system defaults?" "y" && echo "true" || echo "false")
    ENABLE_APPLICATIONS=$(prompt_yes_no "Enable application management?" "y" && echo "true" || echo "false")
    
    # State version
    STATE_VERSION=$(prompt_input "Darwin state version" "6")
    HOME_MANAGER_STATE_VERSION=$(prompt_input "Home Manager state version" "25.05")
    
    # Set network names
    COMPUTER_NAME=$(prompt_input "Computer name (displayed name)" "$FULL_NAME's $(echo $HOSTNAME | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')")
fi

# Step 8: Generate Configuration
print_header "Step 8: Generate Configuration"

echo "Generating host configuration..."

# Create host directory
mkdir -p "$SCRIPT_DIR/hosts/$HOSTNAME"

# Call template generator
"$SCRIPT_DIR/scripts/new-host-template.sh" \
    --platform "$PLATFORM" \
    --hostname "$HOSTNAME" \
    --username "$USERNAME" \
    --fullname "$FULL_NAME" \
    --arch "$ARCH" \
    --rust "$ENABLE_RUST" \
    --nodejs "$ENABLE_NODEJS" \
    --go "$ENABLE_GO" \
    --python "$ENABLE_PYTHON" \
    --java "$ENABLE_JAVA" \
    --zig "$ENABLE_ZIG" \
    --android "$ENABLE_ANDROID" \
    --devops "$ENABLE_DEVOPS" \
    --openssl "$ENABLE_OPENSSL" \
    --dotnet "$ENABLE_DOTNET" \
    --dotnet-runtime-only "$DOTNET_RUNTIME_ONLY" \
    --dotnet-sdk-versions "$DOTNET_SDK_VERSIONS" \
    --dotnet-runtime-versions "$DOTNET_RUNTIME_VERSIONS" \
    --dotnet-aspnetcore "$ENABLE_ASPNETCORE" \
    --dotnet-aspnetcore-versions "$ASPNETCORE_VERSIONS" \
    --dotnet-ef "$ENABLE_EF" \
    --dotnet-outdated "$ENABLE_DOTNET_OUTDATED" \
    --dotnet-repl "$ENABLE_DOTNET_REPL" \
    --dotnet-formatters "$ENABLE_DOTNET_FORMATTERS" \
    --dotnet-paket "$ENABLE_DOTNET_PAKET" \
    --dotnet-nuget-custom "$ENABLE_NUGET_CUSTOM" \
    --dotnet-nuget-sources "$NUGET_SOURCES" \
    --podman "$ENABLE_PODMAN" \
    --docker "$ENABLE_DOCKER" \
    --neovim "$ENABLE_NEOVIM" \
    --neovim-nightly "$NEOVIM_NIGHTLY" \
    --fish "$ENABLE_FISH" \
    --bash "$ENABLE_BASH" \
    --zsh "$ENABLE_ZSH" \
    --nushell "$ENABLE_NUSHELL" \
    --default-shell "$DEFAULT_SHELL" \
    --git "$ENABLE_GIT" \
    --clitools "$ENABLE_CLITOOLS" \
    --state-version "$STATE_VERSION" \
    ${HOME_MANAGER_STATE_VERSION:+--home-manager-state-version "$HOME_MANAGER_STATE_VERSION"} \
    ${ENABLE_DESKTOP:+--desktop "$ENABLE_DESKTOP"} \
    ${ENABLE_HYPRLAND:+--hyprland "$ENABLE_HYPRLAND"} \
    ${ENABLE_WAYBAR:+--waybar "$ENABLE_WAYBAR"} \
    ${ENABLE_GTK:+--gtk "$ENABLE_GTK"} \
    ${ENABLE_XSERVER:+--xserver "$ENABLE_XSERVER"} \
    ${ENABLE_NVIDIA:+--nvidia "$ENABLE_NVIDIA"} \
    ${ENABLE_GRAPHICS:+--graphics "$ENABLE_GRAPHICS"} \
    ${ENABLE_BOOT:+--boot "$ENABLE_BOOT"} \
    ${USE_LATEST_KERNEL:+--latest-kernel "$USE_LATEST_KERNEL"} \
    ${ENABLE_SYSTEM:+--system "$ENABLE_SYSTEM"} \
    ${ENABLE_NETWORKING:+--networking "$ENABLE_NETWORKING"} \
    ${ENABLE_SSH:+--ssh "$ENABLE_SSH"} \
    ${ENABLE_SECURITY:+--security "$ENABLE_SECURITY"} \
    ${ENABLE_AUDIO:+--audio "$ENABLE_AUDIO"} \
    ${ENABLE_LOCALE:+--locale "$ENABLE_LOCALE"} \
    ${TIMEZONE:+--timezone "$TIMEZONE"} \
    ${DOCKER_DATA_ROOT:+--docker-data-root "$DOCKER_DATA_ROOT"} \
    ${ENABLE_OBSERVABILITY:+--observability "$ENABLE_OBSERVABILITY"} \
    ${ENABLE_MINECRAFT:+--minecraft "$ENABLE_MINECRAFT"} \
    ${ENABLE_NIXOS_CLITOOLS:+--nixos-clitools "$ENABLE_NIXOS_CLITOOLS"} \
    ${ENABLE_HOMEBREW:+--homebrew "$ENABLE_HOMEBREW"} \
    ${ENABLE_SYSTEM_DEFAULTS:+--system-defaults "$ENABLE_SYSTEM_DEFAULTS"} \
    ${ENABLE_APPLICATIONS:+--applications "$ENABLE_APPLICATIONS"} \
    ${COMPUTER_NAME:+--computer-name "$COMPUTER_NAME"}

print_success "Created $SCRIPT_DIR/hosts/$HOSTNAME/default.nix"

# Step 9: Generate meta.nix (for auto-discovery by flake.nix and rebuild.sh)
print_header "Step 9: Generate Host Metadata"

# Map platform name to meta.nix type
case "$PLATFORM" in
    darwin) META_TYPE="darwin" ;;
    nixos)  META_TYPE="nixos" ;;
    linux)  META_TYPE="home-manager" ;;
esac

# Determine the hostname used for rebuild.sh auto-detection
if [ "$PLATFORM" = "darwin" ] && [ -n "${COMPUTER_NAME:-}" ]; then
    # Darwin uses networking.hostName which we set to HOSTNAME
    META_HOSTNAME="$HOSTNAME"
else
    META_HOSTNAME="$HOSTNAME"
fi

cat > "$SCRIPT_DIR/hosts/$HOSTNAME/meta.nix" << EOF
{
  type = "$META_TYPE";
  system = "$ARCH";
  hostname = "$META_HOSTNAME";
  username = "$USERNAME";
}
EOF

print_success "Created $SCRIPT_DIR/hosts/$HOSTNAME/meta.nix"
print_success "The flake and rebuild.sh will auto-discover this host -- no manual edits needed."

# For NixOS, handle hardware-configuration.nix
if [ "$PLATFORM" = "nixos" ]; then
    print_header "NixOS Hardware Configuration"
    
    if [ -f /etc/nixos/hardware-configuration.nix ]; then
        if prompt_yes_no "Copy hardware configuration from /etc/nixos/hardware-configuration.nix?" "y"; then
            cp /etc/nixos/hardware-configuration.nix "$SCRIPT_DIR/hosts/$HOSTNAME/"
            print_success "Copied hardware-configuration.nix"
        else
            print_warning "You'll need to manually create hardware-configuration.nix"
            print_warning "Run: sudo nixos-generate-config --show-hardware-config > $SCRIPT_DIR/hosts/$HOSTNAME/hardware-configuration.nix"
        fi
    else
        print_warning "Generating hardware configuration..."
        if command -v nixos-generate-config &> /dev/null; then
            sudo nixos-generate-config --show-hardware-config > "$SCRIPT_DIR/hosts/$HOSTNAME/hardware-configuration.nix"
            print_success "Generated hardware-configuration.nix"
        else
            print_error "nixos-generate-config not found. Please create hardware-configuration.nix manually."
        fi
    fi
fi

# Summary
print_header "Bootstrap Complete!"

echo "Summary:"
echo "  Platform: $PLATFORM"
echo "  Architecture: $ARCH"
echo "  Hostname: $HOSTNAME"
echo "  Username: $USERNAME"
echo "  Default shell: $DEFAULT_SHELL"
echo ""
echo "Generated files:"
echo "  $SCRIPT_DIR/hosts/$HOSTNAME/default.nix"
echo "  $SCRIPT_DIR/hosts/$HOSTNAME/meta.nix"
echo ""

print_success "Next steps:"
echo "  1. Review the generated configuration in hosts/$HOSTNAME/"
echo "  2. Test the configuration:"
if [ "$PLATFORM" = "darwin" ]; then
    echo "     darwin-rebuild build --flake .#$HOSTNAME"
elif [ "$PLATFORM" = "nixos" ]; then
    echo "     sudo nixos-rebuild build --flake .#$HOSTNAME"
else
    echo "     home-manager build --flake .#$USERNAME@$HOSTNAME"
fi
echo "  3. Apply the configuration:"
echo "     ./rebuild.sh"
echo ""

if prompt_yes_no "Would you like to commit these changes?" "n"; then
    cd "$SCRIPT_DIR"
    git add "hosts/$HOSTNAME/"
    git commit -m "Add new host: $HOSTNAME ($PLATFORM)"
    print_success "Changes committed"
fi

print_success "Bootstrap completed successfully!"

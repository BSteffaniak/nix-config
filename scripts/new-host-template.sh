#!/usr/bin/env bash

# Template generator for new host configurations
# Called by bootstrap.sh with configuration options

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform) PLATFORM="$2"; shift 2 ;;
        --hostname) HOSTNAME="$2"; shift 2 ;;
        --username) USERNAME="$2"; shift 2 ;;
        --fullname) FULLNAME="$2"; shift 2 ;;
        --arch) ARCH="$2"; shift 2 ;;
        --rust) ENABLE_RUST="$2"; shift 2 ;;
        --nodejs) ENABLE_NODEJS="$2"; shift 2 ;;
        --go) ENABLE_GO="$2"; shift 2 ;;
        --python) ENABLE_PYTHON="$2"; shift 2 ;;
        --java) ENABLE_JAVA="$2"; shift 2 ;;
        --zig) ENABLE_ZIG="$2"; shift 2 ;;
        --android) ENABLE_ANDROID="$2"; shift 2 ;;
        --devops) ENABLE_DEVOPS="$2"; shift 2 ;;
        --openssl) ENABLE_OPENSSL="$2"; shift 2 ;;
        --dotnet) ENABLE_DOTNET="$2"; shift 2 ;;
        --dotnet-runtime-only) DOTNET_RUNTIME_ONLY="$2"; shift 2 ;;
        --dotnet-sdk-versions) DOTNET_SDK_VERSIONS="$2"; shift 2 ;;
        --dotnet-runtime-versions) DOTNET_RUNTIME_VERSIONS="$2"; shift 2 ;;
        --dotnet-aspnetcore) ENABLE_ASPNETCORE="$2"; shift 2 ;;
        --dotnet-aspnetcore-versions) ASPNETCORE_VERSIONS="$2"; shift 2 ;;
        --dotnet-ef) ENABLE_EF="$2"; shift 2 ;;
        --dotnet-outdated) ENABLE_DOTNET_OUTDATED="$2"; shift 2 ;;
        --dotnet-repl) ENABLE_DOTNET_REPL="$2"; shift 2 ;;
        --dotnet-formatters) ENABLE_DOTNET_FORMATTERS="$2"; shift 2 ;;
        --dotnet-paket) ENABLE_DOTNET_PAKET="$2"; shift 2 ;;
        --dotnet-nuget-custom) ENABLE_NUGET_CUSTOM="$2"; shift 2 ;;
        --dotnet-nuget-sources) NUGET_SOURCES="$2"; shift 2 ;;
        --podman) ENABLE_PODMAN="$2"; shift 2 ;;
        --docker) ENABLE_DOCKER="$2"; shift 2 ;;
        --neovim) ENABLE_NEOVIM="$2"; shift 2 ;;
        --neovim-nightly) NEOVIM_NIGHTLY="$2"; shift 2 ;;
        --fish) ENABLE_FISH="$2"; shift 2 ;;
        --bash) ENABLE_BASH="$2"; shift 2 ;;
        --zsh) ENABLE_ZSH="$2"; shift 2 ;;
        --nushell) ENABLE_NUSHELL="$2"; shift 2 ;;
        --default-shell) DEFAULT_SHELL="$2"; shift 2 ;;
        --git) ENABLE_GIT="$2"; shift 2 ;;
        --clitools) ENABLE_CLITOOLS="$2"; shift 2 ;;
        --desktop) ENABLE_DESKTOP="$2"; shift 2 ;;
        --hyprland) ENABLE_HYPRLAND="$2"; shift 2 ;;
        --waybar) ENABLE_WAYBAR="$2"; shift 2 ;;
        --gtk) ENABLE_GTK="$2"; shift 2 ;;
        --xserver) ENABLE_XSERVER="$2"; shift 2 ;;
        --nvidia) ENABLE_NVIDIA="$2"; shift 2 ;;
        --graphics) ENABLE_GRAPHICS="$2"; shift 2 ;;
        --boot) ENABLE_BOOT="$2"; shift 2 ;;
        --latest-kernel) USE_LATEST_KERNEL="$2"; shift 2 ;;
        --system) ENABLE_SYSTEM="$2"; shift 2 ;;
        --networking) ENABLE_NETWORKING="$2"; shift 2 ;;
        --ssh) ENABLE_SSH="$2"; shift 2 ;;
        --security) ENABLE_SECURITY="$2"; shift 2 ;;
        --audio) ENABLE_AUDIO="$2"; shift 2 ;;
        --locale) ENABLE_LOCALE="$2"; shift 2 ;;
        --timezone) TIMEZONE="$2"; shift 2 ;;
        --docker-data-root) DOCKER_DATA_ROOT="$2"; shift 2 ;;
        --observability) ENABLE_OBSERVABILITY="$2"; shift 2 ;;
        --minecraft) ENABLE_MINECRAFT="$2"; shift 2 ;;
        --nixos-clitools) ENABLE_NIXOS_CLITOOLS="$2"; shift 2 ;;
        --homebrew) ENABLE_HOMEBREW="$2"; shift 2 ;;
        --system-defaults) ENABLE_SYSTEM_DEFAULTS="$2"; shift 2 ;;
        --applications) ENABLE_APPLICATIONS="$2"; shift 2 ;;
        --computer-name) COMPUTER_NAME="$2"; shift 2 ;;
        --state-version) STATE_VERSION="$2"; shift 2 ;;
        --home-manager-state-version) HOME_MANAGER_STATE_VERSION="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate required arguments
if [ -z "$PLATFORM" ] || [ -z "$HOSTNAME" ] || [ -z "$USERNAME" ] || [ -z "$FULLNAME" ]; then
    echo "Error: Missing required arguments"
    echo "Required: --platform, --hostname, --username, --fullname"
    exit 1
fi

# Set defaults
ENABLE_RUST="${ENABLE_RUST:-true}"
ENABLE_NODEJS="${ENABLE_NODEJS:-true}"
ENABLE_GO="${ENABLE_GO:-true}"
ENABLE_PYTHON="${ENABLE_PYTHON:-false}"
ENABLE_JAVA="${ENABLE_JAVA:-false}"
ENABLE_ZIG="${ENABLE_ZIG:-false}"
ENABLE_ANDROID="${ENABLE_ANDROID:-false}"
ENABLE_DEVOPS="${ENABLE_DEVOPS:-true}"
ENABLE_OPENSSL="${ENABLE_OPENSSL:-true}"
ENABLE_DOTNET="${ENABLE_DOTNET:-false}"
DOTNET_RUNTIME_ONLY="${DOTNET_RUNTIME_ONLY:-false}"
DOTNET_SDK_VERSIONS="${DOTNET_SDK_VERSIONS:-}"
DOTNET_RUNTIME_VERSIONS="${DOTNET_RUNTIME_VERSIONS:-}"
ENABLE_ASPNETCORE="${ENABLE_ASPNETCORE:-false}"
ASPNETCORE_VERSIONS="${ASPNETCORE_VERSIONS:-}"
ENABLE_EF="${ENABLE_EF:-true}"
ENABLE_DOTNET_OUTDATED="${ENABLE_DOTNET_OUTDATED:-false}"
ENABLE_DOTNET_REPL="${ENABLE_DOTNET_REPL:-false}"
ENABLE_DOTNET_FORMATTERS="${ENABLE_DOTNET_FORMATTERS:-false}"
ENABLE_DOTNET_PAKET="${ENABLE_DOTNET_PAKET:-false}"
ENABLE_NUGET_CUSTOM="${ENABLE_NUGET_CUSTOM:-false}"
NUGET_SOURCES="${NUGET_SOURCES:-}"
ENABLE_NEOVIM="${ENABLE_NEOVIM:-true}"
NEOVIM_NIGHTLY="${NEOVIM_NIGHTLY:-true}"
ENABLE_FISH="${ENABLE_FISH:-true}"
ENABLE_BASH="${ENABLE_BASH:-true}"
ENABLE_ZSH="${ENABLE_ZSH:-true}"
ENABLE_NUSHELL="${ENABLE_NUSHELL:-true}"
DEFAULT_SHELL="${DEFAULT_SHELL:-fish}"
ENABLE_GIT="${ENABLE_GIT:-true}"
ENABLE_CLITOOLS="${ENABLE_CLITOOLS:-true}"
STATE_VERSION="${STATE_VERSION:-24.11}"
HOME_MANAGER_STATE_VERSION="${HOME_MANAGER_STATE_VERSION:-25.05}"

case "$DEFAULT_SHELL" in
    fish|bash|zsh|nushell) ;;
    *)
        echo "Error: --default-shell must be one of: fish, bash, zsh, nushell"
        exit 1
        ;;
esac

if [ "$DEFAULT_SHELL" = "fish" ]; then ENABLE_FISH="true"; fi
if [ "$DEFAULT_SHELL" = "bash" ]; then ENABLE_BASH="true"; fi
if [ "$DEFAULT_SHELL" = "zsh" ]; then ENABLE_ZSH="true"; fi
if [ "$DEFAULT_SHELL" = "nushell" ]; then ENABLE_NUSHELL="true"; fi

# Generate the configuration file
OUTPUT_FILE="$SCRIPT_DIR/hosts/$HOSTNAME/default.nix"

if [ "$PLATFORM" = "nixos" ]; then
    # Generate NixOS configuration
    cat > "$OUTPUT_FILE" << EOF
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/nixos
EOF

    # Add conditional imports
    if [ "$ENABLE_MINECRAFT" = "true" ]; then
        cat >> "$OUTPUT_FILE" << EOF
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ../../modules/nixos/services/minecraft.nix
EOF
    fi

    cat >> "$OUTPUT_FILE" << EOF
  ];

  # Host-specific settings
  myConfig = {
    username = "$USERNAME";
    fullName = "$FULLNAME";

EOF

    # Boot configuration
    if [ "$ENABLE_BOOT" = "true" ]; then
        cat >> "$OUTPUT_FILE" << EOF
    # Boot configuration
    boot.enable = $ENABLE_BOOT;
    boot.useLatestKernel = ${USE_LATEST_KERNEL:-false};

EOF
    fi

    # Hardware
    if [ "$ENABLE_NVIDIA" = "true" ] || [ "$ENABLE_GRAPHICS" = "true" ]; then
        cat >> "$OUTPUT_FILE" << EOF
    # Hardware
EOF
        if [ "$ENABLE_NVIDIA" = "true" ]; then
            echo "    hardware.nvidia.enable = true;" >> "$OUTPUT_FILE"
        fi
        if [ "$ENABLE_GRAPHICS" = "true" ]; then
            echo "    hardware.graphics.enable = true;" >> "$OUTPUT_FILE"
        fi
        echo "" >> "$OUTPUT_FILE"
    fi

    # Desktop environment
    if [ "$ENABLE_DESKTOP" = "true" ]; then
        cat >> "$OUTPUT_FILE" << EOF
    # Desktop environment
    desktop.enable = $ENABLE_DESKTOP;
EOF
        if [ "$ENABLE_HYPRLAND" = "true" ]; then
            echo "    desktop.hyprland.enable = true;" >> "$OUTPUT_FILE"
        fi
        if [ "$ENABLE_WAYBAR" = "true" ]; then
            echo "    desktop.waybar.enable = true;" >> "$OUTPUT_FILE"
        fi
        if [ "$ENABLE_GTK" = "true" ]; then
            echo "    desktop.gtk.enable = true;" >> "$OUTPUT_FILE"
        fi
        if [ "$ENABLE_XSERVER" = "true" ]; then
            echo "    desktop.xserver.enable = true;" >> "$OUTPUT_FILE"
        fi
        echo "" >> "$OUTPUT_FILE"
    fi

    # Development tools
    cat >> "$OUTPUT_FILE" << EOF
    # Development tools
    development.rust.enable = $ENABLE_RUST;
    development.nodejs.enable = $ENABLE_NODEJS;
    development.go.enable = $ENABLE_GO;
    development.python.enable = $ENABLE_PYTHON;
    development.android.enable = $ENABLE_ANDROID;
    development.devops.enable = $ENABLE_DEVOPS;
EOF
    
    if [ "$ENABLE_ZIG" = "true" ]; then
        echo "    development.zig.enable = true;" >> "$OUTPUT_FILE"
    fi
    if [ "$ENABLE_OPENSSL" = "true" ]; then
        echo "    development.openssl.enable = true;" >> "$OUTPUT_FILE"
    fi

    # .NET Configuration
    if [ "$ENABLE_DOTNET" = "true" ]; then
        echo "    development.dotnet.enable = true;" >> "$OUTPUT_FILE"
        
        if [ "$DOTNET_RUNTIME_ONLY" = "true" ]; then
            echo "    development.dotnet.runtimeOnly = true;" >> "$OUTPUT_FILE"
            
            if [ -n "$DOTNET_RUNTIME_VERSIONS" ]; then
                # Convert space-separated versions to Nix list
                VERSIONS_LIST=$(echo "$DOTNET_RUNTIME_VERSIONS" | tr ' ' '\n' | sed 's/^/      "/' | sed 's/$/"/' | tr '\n' ' ')
                cat >> "$OUTPUT_FILE" << EOF
    development.dotnet.runtimeVersions = [
$VERSIONS_LIST
    ];
EOF
            fi
        else
            if [ -n "$DOTNET_SDK_VERSIONS" ]; then
                # Convert space-separated versions to Nix list
                VERSIONS_LIST=$(echo "$DOTNET_SDK_VERSIONS" | tr ' ' '\n' | sed 's/^/      "/' | sed 's/$/"/' | tr '\n' ' ')
                cat >> "$OUTPUT_FILE" << EOF
    development.dotnet.sdkVersions = [
$VERSIONS_LIST
    ];
EOF
            fi
        fi
        
        if [ "$ENABLE_ASPNETCORE" = "true" ]; then
            echo "    development.dotnet.aspnetcore.enable = true;" >> "$OUTPUT_FILE"
            
            if [ -n "$ASPNETCORE_VERSIONS" ]; then
                VERSIONS_LIST=$(echo "$ASPNETCORE_VERSIONS" | tr ' ' '\n' | sed 's/^/      "/' | sed 's/$/"/' | tr '\n' ' ')
                cat >> "$OUTPUT_FILE" << EOF
    development.dotnet.aspnetcore.versions = [
$VERSIONS_LIST
    ];
EOF
            fi
        fi
        
        if [ "$ENABLE_EF" = "true" ]; then
            echo "    development.dotnet.entityFramework.enable = true;" >> "$OUTPUT_FILE"
        fi
        
        # Global tools
        if [ "$ENABLE_DOTNET_OUTDATED" = "true" ] || [ "$ENABLE_DOTNET_REPL" = "true" ] || [ "$ENABLE_DOTNET_FORMATTERS" = "true" ] || [ "$ENABLE_DOTNET_PAKET" = "true" ]; then
            if [ "$ENABLE_DOTNET_OUTDATED" = "true" ]; then
                echo "    development.dotnet.globalTools.enableOutdated = true;" >> "$OUTPUT_FILE"
            fi
            if [ "$ENABLE_DOTNET_REPL" = "true" ]; then
                echo "    development.dotnet.globalTools.enableRepl = true;" >> "$OUTPUT_FILE"
            fi
            if [ "$ENABLE_DOTNET_FORMATTERS" = "true" ]; then
                echo "    development.dotnet.globalTools.enableFormatters = true;" >> "$OUTPUT_FILE"
            fi
            if [ "$ENABLE_DOTNET_PAKET" = "true" ]; then
                echo "    development.dotnet.globalTools.enablePaket = true;" >> "$OUTPUT_FILE"
            fi
        fi
        
        # NuGet configuration
        if [ "$ENABLE_NUGET_CUSTOM" = "true" ]; then
            echo "    development.dotnet.nuget.enableCustomSources = true;" >> "$OUTPUT_FILE"
            
            if [ -n "$NUGET_SOURCES" ]; then
                echo "    development.dotnet.nuget.sources = {" >> "$OUTPUT_FILE"
                
                # Parse pipe-separated sources (format: name=url|name2=url2)
                IFS='|' read -ra SOURCES <<< "$NUGET_SOURCES"
                for source in "${SOURCES[@]}"; do
                    if [ -n "$source" ]; then
                        SOURCE_NAME=$(echo "$source" | cut -d'=' -f1)
                        SOURCE_URL=$(echo "$source" | cut -d'=' -f2)
                        echo "      \"$SOURCE_NAME\" = \"$SOURCE_URL\";" >> "$OUTPUT_FILE"
                    fi
                done
                
                echo "    };" >> "$OUTPUT_FILE"
            fi
        fi
    fi

    # Shell and editors
    cat >> "$OUTPUT_FILE" << EOF

    # Shell and editors
    shell.default = "$DEFAULT_SHELL";
    shell.fish.enable = $ENABLE_FISH;
    shell.bash.enable = $ENABLE_BASH;
    shell.zsh.enable = $ENABLE_ZSH;
    shell.nushell.enable = $ENABLE_NUSHELL;
    shell.git.enable = $ENABLE_GIT;
    editors.neovim.enable = $ENABLE_NEOVIM;
    editors.neovim.useNightly = $NEOVIM_NIGHTLY;

    # CLI tools
    cliTools.enable = $ENABLE_CLITOOLS;
EOF

    if [ "$ENABLE_NIXOS_CLITOOLS" = "true" ]; then
        echo "    nixos.cliTools.enable = true;" >> "$OUTPUT_FILE"
    fi

    # Services
    if [ "$ENABLE_DOCKER" = "true" ] || [ "$ENABLE_OBSERVABILITY" = "true" ] || [ "$ENABLE_MINECRAFT" = "true" ]; then
        cat >> "$OUTPUT_FILE" << EOF

    # Services
EOF
        if [ "$ENABLE_DOCKER" = "true" ]; then
            echo "    services.docker.enable = true;" >> "$OUTPUT_FILE"
            if [ -n "$DOCKER_DATA_ROOT" ]; then
                echo "    services.docker.dataRoot = \"$DOCKER_DATA_ROOT\";" >> "$OUTPUT_FILE"
            fi
        fi
        if [ "$ENABLE_OBSERVABILITY" = "true" ]; then
            echo "    services.observability.enable = true;" >> "$OUTPUT_FILE"
        fi
        if [ "$ENABLE_MINECRAFT" = "true" ]; then
            echo "    services.minecraft.enable = true;" >> "$OUTPUT_FILE"
        fi
    fi

    # System configuration
    if [ "$ENABLE_SYSTEM" = "true" ]; then
        cat >> "$OUTPUT_FILE" << EOF

    # System configuration
    system.enable = $ENABLE_SYSTEM;
EOF
        if [ "$ENABLE_NETWORKING" = "true" ]; then
            cat >> "$OUTPUT_FILE" << EOF
    system.networking.enable = true;
    system.networking.hostName = "$HOSTNAME";
EOF
            if [ "$ENABLE_SSH" = "true" ]; then
                echo "    system.networking.enableSSH = true;" >> "$OUTPUT_FILE"
            fi
        fi
        if [ "$ENABLE_SECURITY" = "true" ]; then
            echo "    system.security.enable = true;" >> "$OUTPUT_FILE"
        fi
        if [ "$ENABLE_AUDIO" = "true" ]; then
            echo "    system.audio.enable = true;" >> "$OUTPUT_FILE"
        fi
        if [ "$ENABLE_LOCALE" = "true" ]; then
            cat >> "$OUTPUT_FILE" << EOF
    system.locale.enable = true;
    system.locale.timeZone = "${TIMEZONE:-America/New_York}";
EOF
        fi
    fi

    # User configuration
    cat >> "$OUTPUT_FILE" << EOF
  };

  # User configuration
  users.users.$USERNAME = {
    isNormalUser = true;
    description = "$FULLNAME";
    extraGroups = [
      "networkmanager"
      "wheel"
EOF

    if [ "$ENABLE_DOCKER" = "true" ]; then
        echo '      "docker"' >> "$OUTPUT_FILE"
    fi

    cat >> "$OUTPUT_FILE" << EOF
    ];
    packages = with pkgs; [
      # Add user-specific packages here
    ];
  };

  # System packages specific to this host
  environment.systemPackages = with pkgs; [
    inputs.home-manager.packages."\${pkgs.system}".default
  ];

  # Fonts
  fonts = {
    packages = with pkgs; [
      font-awesome
      fira-code
      fira-code-symbols
      nerd-fonts.fira-code
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "$STATE_VERSION";
}
EOF

elif [ "$PLATFORM" = "darwin" ]; then
    # Generate Darwin configuration
    cat > "$OUTPUT_FILE" << EOF
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/common
    ../../modules/darwin
  ];

  # Host-specific settings
  myConfig = {
    username = "$USERNAME";
    fullName = "$FULLNAME";
    homeManagerStateVersion = "$HOME_MANAGER_STATE_VERSION";

    # Development tools
    development.rust.enable = $ENABLE_RUST;
    development.nodejs.enable = $ENABLE_NODEJS;
    development.go.enable = $ENABLE_GO;
    development.python.enable = $ENABLE_PYTHON;
    development.android.enable = $ENABLE_ANDROID;
    development.devops.enable = $ENABLE_DEVOPS;
EOF

    if [ "$ENABLE_PODMAN" = "true" ]; then
        echo "    development.podman.enable = true;" >> "$OUTPUT_FILE"
    fi
    if [ "$ENABLE_OPENSSL" = "true" ]; then
        echo "    development.openssl.enable = true;" >> "$OUTPUT_FILE"
    fi
    if [ "$ENABLE_JAVA" = "true" ]; then
        echo "    development.java.enable = true;" >> "$OUTPUT_FILE"
    fi

    # .NET Configuration (Darwin)
    if [ "$ENABLE_DOTNET" = "true" ]; then
        echo "    development.dotnet.enable = true;" >> "$OUTPUT_FILE"
        
        if [ "$DOTNET_RUNTIME_ONLY" = "true" ]; then
            echo "    development.dotnet.runtimeOnly = true;" >> "$OUTPUT_FILE"
            
            if [ -n "$DOTNET_RUNTIME_VERSIONS" ]; then
                VERSIONS_LIST=$(echo "$DOTNET_RUNTIME_VERSIONS" | tr ' ' '\n' | sed 's/^/      "/' | sed 's/$/"/' | tr '\n' ' ')
                cat >> "$OUTPUT_FILE" << EOF
    development.dotnet.runtimeVersions = [
$VERSIONS_LIST
    ];
EOF
            fi
        else
            if [ -n "$DOTNET_SDK_VERSIONS" ]; then
                VERSIONS_LIST=$(echo "$DOTNET_SDK_VERSIONS" | tr ' ' '\n' | sed 's/^/      "/' | sed 's/$/"/' | tr '\n' ' ')
                cat >> "$OUTPUT_FILE" << EOF
    development.dotnet.sdkVersions = [
$VERSIONS_LIST
    ];
EOF
            fi
        fi
        
        if [ "$ENABLE_ASPNETCORE" = "true" ]; then
            echo "    development.dotnet.aspnetcore.enable = true;" >> "$OUTPUT_FILE"
            
            if [ -n "$ASPNETCORE_VERSIONS" ]; then
                VERSIONS_LIST=$(echo "$ASPNETCORE_VERSIONS" | tr ' ' '\n' | sed 's/^/      "/' | sed 's/$/"/' | tr '\n' ' ')
                cat >> "$OUTPUT_FILE" << EOF
    development.dotnet.aspnetcore.versions = [
$VERSIONS_LIST
    ];
EOF
            fi
        fi
        
        if [ "$ENABLE_EF" = "true" ]; then
            echo "    development.dotnet.entityFramework.enable = true;" >> "$OUTPUT_FILE"
        fi
        
        if [ "$ENABLE_DOTNET_OUTDATED" = "true" ] || [ "$ENABLE_DOTNET_REPL" = "true" ] || [ "$ENABLE_DOTNET_FORMATTERS" = "true" ] || [ "$ENABLE_DOTNET_PAKET" = "true" ]; then
            if [ "$ENABLE_DOTNET_OUTDATED" = "true" ]; then
                echo "    development.dotnet.globalTools.enableOutdated = true;" >> "$OUTPUT_FILE"
            fi
            if [ "$ENABLE_DOTNET_REPL" = "true" ]; then
                echo "    development.dotnet.globalTools.enableRepl = true;" >> "$OUTPUT_FILE"
            fi
            if [ "$ENABLE_DOTNET_FORMATTERS" = "true" ]; then
                echo "    development.dotnet.globalTools.enableFormatters = true;" >> "$OUTPUT_FILE"
            fi
            if [ "$ENABLE_DOTNET_PAKET" = "true" ]; then
                echo "    development.dotnet.globalTools.enablePaket = true;" >> "$OUTPUT_FILE"
            fi
        fi
        
        if [ "$ENABLE_NUGET_CUSTOM" = "true" ]; then
            echo "    development.dotnet.nuget.enableCustomSources = true;" >> "$OUTPUT_FILE"
            
            if [ -n "$NUGET_SOURCES" ]; then
                echo "    development.dotnet.nuget.sources = {" >> "$OUTPUT_FILE"
                
                IFS='|' read -ra SOURCES <<< "$NUGET_SOURCES"
                for source in "${SOURCES[@]}"; do
                    if [ -n "$source" ]; then
                        SOURCE_NAME=$(echo "$source" | cut -d'=' -f1)
                        SOURCE_URL=$(echo "$source" | cut -d'=' -f2)
                        echo "      \"$SOURCE_NAME\" = \"$SOURCE_URL\";" >> "$OUTPUT_FILE"
                    fi
                done
                
                echo "    };" >> "$OUTPUT_FILE"
            fi
        fi
    fi

    cat >> "$OUTPUT_FILE" << EOF

    # Shell and editors
    shell.default = "$DEFAULT_SHELL";
    shell.fish.enable = $ENABLE_FISH;
    shell.bash.enable = $ENABLE_BASH;
    shell.zsh.enable = $ENABLE_ZSH;
    shell.nushell.enable = $ENABLE_NUSHELL;
    shell.git.enable = $ENABLE_GIT;
    editors.neovim.enable = $ENABLE_NEOVIM;
    editors.neovim.useNightly = $NEOVIM_NIGHTLY;

    # CLI tools
    cliTools.enable = $ENABLE_CLITOOLS;

    # Darwin-specific
    darwin.homebrew.enable = ${ENABLE_HOMEBREW:-true};
    darwin.systemDefaults.enable = ${ENABLE_SYSTEM_DEFAULTS:-true};
    darwin.applications.enable = ${ENABLE_APPLICATIONS:-true};
  };

  # Networking
  networking.hostName = "$HOSTNAME";
EOF

    if [ -n "$COMPUTER_NAME" ]; then
        echo "  networking.computerName = \"$COMPUTER_NAME\";" >> "$OUTPUT_FILE"
    fi

    cat >> "$OUTPUT_FILE" << EOF

  # User configuration
  system.primaryUser = "$USERNAME";

  # System version
  system.stateVersion = ${STATE_VERSION:-6};

  # Platform
  nixpkgs.hostPlatform = "$ARCH";
}
EOF

else
    echo "Error: Unknown platform: $PLATFORM"
    exit 1
fi

echo "Generated configuration: $OUTPUT_FILE"

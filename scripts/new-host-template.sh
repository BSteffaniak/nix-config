#!/usr/bin/env bash

# Template generator for new host configurations.
# Called by bootstrap.sh; can also be used standalone.
#
# Generates hosts/<hostname>/default.nix (system-level) and
# hosts/<hostname>/home.nix (user-level). Host identity (hostname, username,
# state versions, platform) comes from meta.nix, which bootstrap.sh writes.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ $# -gt 0 ]]; do
	case $1 in
	--platform)
		PLATFORM="$2"
		shift 2
		;;
	--hostname)
		HOSTNAME="$2"
		shift 2
		;;
	--username)
		USERNAME="$2"
		shift 2
		;;
	--fullname)
		FULLNAME="$2"
		shift 2
		;;
	--arch)
		ARCH="$2"
		shift 2
		;;
	--rust)
		ENABLE_RUST="$2"
		shift 2
		;;
	--nodejs)
		ENABLE_NODEJS="$2"
		shift 2
		;;
	--go)
		ENABLE_GO="$2"
		shift 2
		;;
	--python)
		ENABLE_PYTHON="$2"
		shift 2
		;;
	--java)
		ENABLE_JAVA="$2"
		shift 2
		;;
	--zig)
		ENABLE_ZIG="$2"
		shift 2
		;;
	--android)
		ENABLE_ANDROID="$2"
		shift 2
		;;
	--devops)
		ENABLE_DEVOPS="$2"
		shift 2
		;;
	--openssl)
		ENABLE_OPENSSL="$2"
		shift 2
		;;
	--dotnet)
		ENABLE_DOTNET="$2"
		shift 2
		;;
	--dotnet-runtime-only)
		DOTNET_RUNTIME_ONLY="$2"
		shift 2
		;;
	--dotnet-sdk-versions)
		DOTNET_SDK_VERSIONS="$2"
		shift 2
		;;
	--dotnet-runtime-versions)
		DOTNET_RUNTIME_VERSIONS="$2"
		shift 2
		;;
	--dotnet-aspnetcore)
		ENABLE_ASPNETCORE="$2"
		shift 2
		;;
	--dotnet-aspnetcore-versions)
		ASPNETCORE_VERSIONS="$2"
		shift 2
		;;
	--dotnet-ef)
		ENABLE_EF="$2"
		shift 2
		;;
	--dotnet-outdated)
		ENABLE_DOTNET_OUTDATED="$2"
		shift 2
		;;
	--dotnet-repl)
		ENABLE_DOTNET_REPL="$2"
		shift 2
		;;
	--dotnet-formatters)
		ENABLE_DOTNET_FORMATTERS="$2"
		shift 2
		;;
	--dotnet-paket)
		ENABLE_DOTNET_PAKET="$2"
		shift 2
		;;
	--dotnet-nuget-custom)
		ENABLE_NUGET_CUSTOM="$2"
		shift 2
		;;
	--dotnet-nuget-sources)
		NUGET_SOURCES="$2"
		shift 2
		;;
	--podman)
		ENABLE_PODMAN="$2"
		shift 2
		;;
	--docker)
		ENABLE_DOCKER="$2"
		shift 2
		;;
	--neovim)
		ENABLE_NEOVIM="$2"
		shift 2
		;;
	--neovim-nightly)
		NEOVIM_NIGHTLY="$2"
		shift 2
		;;
	--fish)
		ENABLE_FISH="$2"
		shift 2
		;;
	--bash)
		ENABLE_BASH="$2"
		shift 2
		;;
	--zsh)
		ENABLE_ZSH="$2"
		shift 2
		;;
	--nushell)
		ENABLE_NUSHELL="$2"
		shift 2
		;;
	--default-shell)
		DEFAULT_SHELL="$2"
		shift 2
		;;
	--git)
		ENABLE_GIT="$2"
		shift 2
		;;
	--clitools)
		ENABLE_CLITOOLS="$2"
		shift 2
		;;
	--desktop)
		ENABLE_DESKTOP="$2"
		shift 2
		;;
	--hyprland)
		ENABLE_HYPRLAND="$2"
		shift 2
		;;
	--waybar)
		ENABLE_WAYBAR="$2"
		shift 2
		;;
	--gtk)
		ENABLE_GTK="$2"
		shift 2
		;;
	--xserver)
		ENABLE_XSERVER="$2"
		shift 2
		;;
	--nvidia)
		ENABLE_NVIDIA="$2"
		shift 2
		;;
	--graphics)
		ENABLE_GRAPHICS="$2"
		shift 2
		;;
	--boot)
		ENABLE_BOOT="$2"
		shift 2
		;;
	--latest-kernel)
		USE_LATEST_KERNEL="$2"
		shift 2
		;;
	--system)
		ENABLE_SYSTEM="$2"
		shift 2
		;;
	--networking)
		ENABLE_NETWORKING="$2"
		shift 2
		;;
	--ssh)
		ENABLE_SSH="$2"
		shift 2
		;;
	--security)
		ENABLE_SECURITY="$2"
		shift 2
		;;
	--audio)
		ENABLE_AUDIO="$2"
		shift 2
		;;
	--locale)
		ENABLE_LOCALE="$2"
		shift 2
		;;
	--timezone)
		TIMEZONE="$2"
		shift 2
		;;
	--docker-data-root)
		DOCKER_DATA_ROOT="$2"
		shift 2
		;;
	--observability)
		ENABLE_OBSERVABILITY="$2"
		shift 2
		;;
	--minecraft)
		ENABLE_MINECRAFT="$2"
		shift 2
		;;
	--homebrew)
		ENABLE_HOMEBREW="$2"
		shift 2
		;;
	--system-defaults)
		ENABLE_SYSTEM_DEFAULTS="$2"
		shift 2
		;;
	--applications)
		ENABLE_APPLICATIONS="$2"
		shift 2
		;;
	--computer-name)
		COMPUTER_NAME="$2"
		shift 2
		;;
	# Accepted for backwards compatibility; state versions now live in meta.nix.
	--state-version | --home-manager-state-version) shift 2 ;;
	*)
		echo "Unknown option: $1"
		exit 1
		;;
	esac
done

if [ -z "${PLATFORM:-}" ] || [ -z "${HOSTNAME:-}" ] || [ -z "${USERNAME:-}" ] || [ -z "${FULLNAME:-}" ]; then
	echo "Error: Missing required arguments"
	echo "Required: --platform, --hostname, --username, --fullname"
	exit 1
fi

# Defaults
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
ENABLE_PODMAN="${ENABLE_PODMAN:-false}"
ENABLE_DOCKER="${ENABLE_DOCKER:-false}"
ENABLE_NEOVIM="${ENABLE_NEOVIM:-true}"
NEOVIM_NIGHTLY="${NEOVIM_NIGHTLY:-true}"
ENABLE_FISH="${ENABLE_FISH:-true}"
ENABLE_BASH="${ENABLE_BASH:-true}"
ENABLE_ZSH="${ENABLE_ZSH:-true}"
ENABLE_NUSHELL="${ENABLE_NUSHELL:-true}"
DEFAULT_SHELL="${DEFAULT_SHELL:-}"
ENABLE_GIT="${ENABLE_GIT:-true}"
ENABLE_CLITOOLS="${ENABLE_CLITOOLS:-true}"
ENABLE_SSH="${ENABLE_SSH:-true}"

if [ -n "$DEFAULT_SHELL" ]; then
	case "$DEFAULT_SHELL" in
	fish | bash | zsh | nushell) ;;
	*)
		echo "Error: --default-shell must be one of: fish, bash, zsh, nushell"
		exit 1
		;;
	esac
	case "$DEFAULT_SHELL" in
	fish) ENABLE_FISH=true ;;
	bash) ENABLE_BASH=true ;;
	zsh) ENABLE_ZSH=true ;;
	nushell) ENABLE_NUSHELL=true ;;
	esac
fi

HOST_DIR="$REPO_DIR/hosts/$HOSTNAME"
mkdir -p "$HOST_DIR"
SYSTEM_FILE="$HOST_DIR/default.nix"
HOME_FILE="$HOST_DIR/home.nix"

# ── helpers ─────────────────────────────────────────────────────────

# emit <file> <line>: append a line
emit() { printf '%s\n' "$2" >>"$1"; }
# emit_if <file> <bool> <line>
emit_if() { [ "$2" = "true" ] && emit "$1" "$3" || true; }
# nix_list "a b c" -> [ "a" "b" "c" ] on multiple lines with given indent
nix_list() {
	local indent="$1"
	shift
	local out="["
	for v in $*; do out+=$'\n'"$indent  \"$v\""; done
	out+=$'\n'"$indent]"
	printf '%s' "$out"
}

# ── home.nix (user-level; identical shape for every platform) ──────

cat >"$HOME_FILE" <<EOF
# User-level configuration for $HOSTNAME.
# System-level settings live in default.nix; host identity in meta.nix.
{ ... }:

{
  myConfig = {
    # Development environments
    development.rust.enable = $ENABLE_RUST;
    development.nodejs.enable = $ENABLE_NODEJS;
    development.go.enable = $ENABLE_GO;
    development.python.enable = $ENABLE_PYTHON;
EOF
emit_if "$HOME_FILE" "$ENABLE_JAVA" "    development.java.enable = true;"
emit_if "$HOME_FILE" "$ENABLE_ZIG" "    development.zig.enable = true;"
emit_if "$HOME_FILE" "$ENABLE_ANDROID" "    development.android.enable = true;"
emit_if "$HOME_FILE" "$ENABLE_OPENSSL" "    development.openssl.enable = true;"

if [ "$ENABLE_DOTNET" = "true" ]; then
	emit "$HOME_FILE" ""
	emit "$HOME_FILE" "    # .NET"
	emit "$HOME_FILE" "    development.dotnet.enable = true;"
	if [ "$DOTNET_RUNTIME_ONLY" = "true" ]; then
		emit "$HOME_FILE" "    development.dotnet.runtimeOnly = true;"
		[ -n "$DOTNET_RUNTIME_VERSIONS" ] && emit "$HOME_FILE" "    development.dotnet.runtimeVersions = $(nix_list '    ' $DOTNET_RUNTIME_VERSIONS);"
	else
		[ -n "$DOTNET_SDK_VERSIONS" ] && emit "$HOME_FILE" "    development.dotnet.sdkVersions = $(nix_list '    ' $DOTNET_SDK_VERSIONS);"
		if [ "$ENABLE_ASPNETCORE" = "true" ]; then
			emit "$HOME_FILE" "    development.dotnet.aspnetcore.enable = true;"
			[ -n "$ASPNETCORE_VERSIONS" ] && emit "$HOME_FILE" "    development.dotnet.aspnetcore.versions = $(nix_list '    ' $ASPNETCORE_VERSIONS);"
		fi
		emit_if "$HOME_FILE" "$([ "$ENABLE_EF" = "false" ] && echo true || echo false)" "    development.dotnet.entityFramework.enable = false;"
		emit_if "$HOME_FILE" "$ENABLE_DOTNET_OUTDATED" "    development.dotnet.globalTools.enableOutdated = true;"
		emit_if "$HOME_FILE" "$ENABLE_DOTNET_REPL" "    development.dotnet.globalTools.enableRepl = true;"
		emit_if "$HOME_FILE" "$ENABLE_DOTNET_FORMATTERS" "    development.dotnet.globalTools.enableFormatters = true;"
		emit_if "$HOME_FILE" "$ENABLE_DOTNET_PAKET" "    development.dotnet.globalTools.enablePaket = true;"
	fi
	if [ "$ENABLE_NUGET_CUSTOM" = "true" ]; then
		emit "$HOME_FILE" "    development.dotnet.nuget.enableCustomSources = true;"
		if [ -n "$NUGET_SOURCES" ]; then
			emit "$HOME_FILE" "    development.dotnet.nuget.sources = {"
			IFS='|' read -ra SOURCES <<<"$NUGET_SOURCES"
			for source in "${SOURCES[@]}"; do
				[ -n "$source" ] || continue
				emit "$HOME_FILE" "      \"${source%%=*}\" = \"${source#*=}\";"
			done
			emit "$HOME_FILE" "    };"
		fi
	fi
fi

if [ "$ENABLE_DEVOPS" = "true" ] || [ "$ENABLE_PODMAN" = "true" ]; then
	emit "$HOME_FILE" ""
	emit "$HOME_FILE" "    # Containers and DevOps"
	emit_if "$HOME_FILE" "$ENABLE_PODMAN" "    containers.podman.enable = true;"
	emit_if "$HOME_FILE" "$ENABLE_DEVOPS" "    containers.tools.enable = true;"
	emit_if "$HOME_FILE" "$ENABLE_DEVOPS" "    devops.kubernetes.enable = true;"
	emit_if "$HOME_FILE" "$ENABLE_DEVOPS" "    devops.cloud.enable = true;"
	emit_if "$HOME_FILE" "$ENABLE_DEVOPS" "    devops.infrastructure.enable = true;"
fi

cat >>"$HOME_FILE" <<EOF

    # Editors
    editors.neovim.enable = $ENABLE_NEOVIM;
    editors.neovim.useNightly = $NEOVIM_NIGHTLY;

    # Shell tooling
    shell.git.enable = $ENABLE_GIT;
    shell.ssh.enable = $ENABLE_SSH;

    # CLI tools
    cliTools = {
      terminals.enableAll = $ENABLE_CLITOOLS;
      monitoring.enableAll = $ENABLE_CLITOOLS;
      fileTools.enableAll = $ENABLE_CLITOOLS;
      formatters.enableAll = $ENABLE_CLITOOLS;
      utilities.enableAll = $ENABLE_CLITOOLS;
    };
  };
}
EOF

# ── default.nix (system-level) ──────────────────────────────────────

if [ "$PLATFORM" = "nixos" ]; then
	cat >"$SYSTEM_FILE" <<EOF
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/nixos
  ];

  # System-level settings. User tools live in home.nix; identity in meta.nix.
  myConfig = {
EOF
	if [ "${ENABLE_BOOT:-false}" = "true" ]; then
		emit "$SYSTEM_FILE" "    # Boot"
		emit "$SYSTEM_FILE" "    boot.enable = true;"
		emit "$SYSTEM_FILE" "    boot.useLatestKernel = ${USE_LATEST_KERNEL:-false};"
		emit "$SYSTEM_FILE" ""
	fi
	if [ "${ENABLE_NVIDIA:-false}" = "true" ] || [ "${ENABLE_GRAPHICS:-false}" = "true" ]; then
		emit "$SYSTEM_FILE" "    # Hardware"
		emit_if "$SYSTEM_FILE" "${ENABLE_NVIDIA:-false}" "    hardware.nvidia.enable = true;"
		emit_if "$SYSTEM_FILE" "${ENABLE_GRAPHICS:-false}" "    hardware.graphics.enable = true;"
		emit "$SYSTEM_FILE" ""
	fi
	if [ "${ENABLE_DESKTOP:-false}" = "true" ]; then
		emit "$SYSTEM_FILE" "    # Desktop environment"
		emit_if "$SYSTEM_FILE" "${ENABLE_HYPRLAND:-false}" "    desktop.hyprland.enable = true;"
		emit_if "$SYSTEM_FILE" "${ENABLE_WAYBAR:-false}" "    desktop.waybar.enable = true;"
		emit_if "$SYSTEM_FILE" "${ENABLE_GTK:-false}" "    desktop.gtk.enable = true;"
		emit_if "$SYSTEM_FILE" "${ENABLE_XSERVER:-false}" "    desktop.xserver.enable = true;"
		emit "$SYSTEM_FILE" ""
	fi
	cat >>"$SYSTEM_FILE" <<EOF
    # Login shells
${DEFAULT_SHELL:+    shell.default = "$DEFAULT_SHELL";
}    shell.fish.enable = $ENABLE_FISH;
    shell.bash.enable = $ENABLE_BASH;
    shell.zsh.enable = $ENABLE_ZSH;
    shell.nushell.enable = $ENABLE_NUSHELL;

    # Services
    services.sshd.enable = $ENABLE_SSH;
EOF
	if [ "$ENABLE_DOCKER" = "true" ]; then
		emit "$SYSTEM_FILE" "    services.docker.enable = true;"
		[ -n "${DOCKER_DATA_ROOT:-}" ] && emit "$SYSTEM_FILE" "    services.docker.dataRoot = \"$DOCKER_DATA_ROOT\";"
	fi
	emit_if "$SYSTEM_FILE" "${ENABLE_OBSERVABILITY:-false}" "    services.observability.enable = true;"
	emit_if "$SYSTEM_FILE" "${ENABLE_MINECRAFT:-false}" "    services.minecraft.enable = true;"

	if [ "${ENABLE_SYSTEM:-false}" = "true" ]; then
		emit "$SYSTEM_FILE" ""
		emit "$SYSTEM_FILE" "    # System configuration"
		emit_if "$SYSTEM_FILE" "${ENABLE_NETWORKING:-false}" "    system.networking.enable = true;"
		emit_if "$SYSTEM_FILE" "${ENABLE_SECURITY:-false}" "    system.security.enable = true;"
		emit_if "$SYSTEM_FILE" "${ENABLE_AUDIO:-false}" "    system.audio.enable = true;"
		if [ "${ENABLE_LOCALE:-false}" = "true" ]; then
			emit "$SYSTEM_FILE" "    system.locale.enable = true;"
			emit "$SYSTEM_FILE" "    system.locale.timeZone = \"${TIMEZONE:-America/New_York}\";"
		fi
	fi

	cat >>"$SYSTEM_FILE" <<EOF
  };

  users.users.\${config.myConfig.username} = {
    isNormalUser = true;
    description = "$FULLNAME";
    extraGroups = [
      "networkmanager"
      "wheel"
EOF
	emit_if "$SYSTEM_FILE" "$ENABLE_DOCKER" '      "docker"'
	cat >>"$SYSTEM_FILE" <<EOF
    ];
  };

  fonts.packages = with pkgs; [
    font-awesome
    fira-code
    fira-code-symbols
    nerd-fonts.fira-code
  ];
}
EOF

elif [ "$PLATFORM" = "darwin" ]; then
	cat >"$SYSTEM_FILE" <<EOF
{ ... }:

{
  imports = [
    ../../modules/common
    ../../modules/darwin
  ];

  # System-level settings. User tools live in home.nix; identity in meta.nix.
  myConfig = {
    # Login shells
${DEFAULT_SHELL:+    shell.default = "$DEFAULT_SHELL";
}    shell.fish.enable = $ENABLE_FISH;
    shell.bash.enable = $ENABLE_BASH;
    shell.zsh.enable = $ENABLE_ZSH;
    shell.nushell.enable = $ENABLE_NUSHELL;

    services.sshd.enable = $ENABLE_SSH;

    # Darwin-specific
    darwin.homebrew.enable = ${ENABLE_HOMEBREW:-true};
    darwin.systemDefaults.enable = ${ENABLE_SYSTEM_DEFAULTS:-true};
    darwin.applications.enable = ${ENABLE_APPLICATIONS:-true};
EOF
	emit_if "$SYSTEM_FILE" "$ENABLE_ANDROID" "    darwin.androidStudio.enable = true;"
	emit "$SYSTEM_FILE" "  };"
	[ -n "${COMPUTER_NAME:-}" ] && {
		emit "$SYSTEM_FILE" ""
		emit "$SYSTEM_FILE" "  networking.computerName = \"$COMPUTER_NAME\";"
	}
	emit "$SYSTEM_FILE" "}"

elif [ "$PLATFORM" = "linux" ]; then
	# Standalone home-manager: no system file.
	:
else
	echo "Error: Unknown platform: $PLATFORM"
	exit 1
fi

echo "Generated: $HOME_FILE"
[ -f "$SYSTEM_FILE" ] && echo "Generated: $SYSTEM_FILE"

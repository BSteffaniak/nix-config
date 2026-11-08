#!/usr/bin/env bash

# Auto-detect host and rebuild configuration
# Usage: ./rebuild.sh [--boot] [--diff|--compare] [additional args...]
#
# Hosts are discovered automatically from hosts/*/meta.nix files.
# No manual edits needed when adding new hosts.

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/scripts/host-common.sh"
source "$SCRIPT_DIR/scripts/rebuild-onboarding.sh"
PREFLIGHT_DIFF=false
FORCE_DIFF=false
for arg in "$@"; do
	case "$arg" in --diff | --compare) PREFLIGHT_DIFF=true ;; esac
done

# ── Host Discovery ─────────────────────────────────────────────────
# Parse meta.nix files to build a hostname -> (host_dir, type) mapping.
# This replaces the old hardcoded case statement.
discover_host() {
	local current_hostname="$1"

	for meta_file in "$SCRIPT_DIR"/hosts/*/meta.nix; do
		[ -f "$meta_file" ] || continue

		local host_dir
		host_dir="$(dirname "$meta_file")"
		local host_name
		host_name="$(basename "$host_dir")"

		# Extract fields from meta.nix using simple pattern matching.
		# This avoids requiring nix to be in PATH for basic detection.
		local meta_hostname meta_type meta_username
		meta_hostname="$(sed -n 's/.*hostname *= *"\([^"]*\)".*/\1/p' "$meta_file" | head -1)"
		meta_type="$(sed -n 's/.*type *= *"\([^"]*\)".*/\1/p' "$meta_file" | head -1)"
		meta_username="$(sed -n 's/.*username *= *"\([^"]*\)".*/\1/p' "$meta_file" | head -1)"

		if [ "$meta_hostname" = "$current_hostname" ]; then
			HOST_NAME="$host_name"
			HOST_TYPE="$meta_type"
			HOST_USERNAME="$meta_username"
			return 0
		fi
	done

	return 1
}

# Detect current host
CURRENT_HOSTNAME=$(hostname)

if ! discover_host "$CURRENT_HOSTNAME"; then
	recover_unknown_host || exit 1
fi

# Derive rebuild command and flake path from host type
case "$HOST_TYPE" in
"nixos")
	FLAKE_PATH="path:$SCRIPT_DIR#$HOST_NAME"
	BASE_REBUILD_CMD="nixos-rebuild"
	NEEDS_SUDO=true
	PLATFORM="NixOS"
	CURRENT_SYSTEM="/run/current-system"
	;;
"darwin")
	FLAKE_PATH="path:$SCRIPT_DIR#$HOST_NAME"
	BASE_REBUILD_CMD="darwin-rebuild"
	NEEDS_SUDO=true
	PLATFORM="Darwin"
	CURRENT_SYSTEM="/run/current-system"
	;;
"home-manager")
	FLAKE_PATH="path:$SCRIPT_DIR#${HOST_USERNAME}@${HOST_NAME}"
	BASE_REBUILD_CMD="home-manager"
	NEEDS_SUDO=false
	PLATFORM="Home-Manager"
	CURRENT_SYSTEM=""
	;;
*)
	echo "Unknown host type: $HOST_TYPE (from hosts/$HOST_NAME/meta.nix)"
	exit 1
	;;
esac

# ── Argument Handling ──────────────────────────────────────────────
ACTION="switch"
DIFF_MODE="$FORCE_DIFF"
EXTRA_ARGS=()
# Bash 3.2 treats empty arrays as unset under nounset; guard expansions below.

for arg in "$@"; do
	if [[ "$arg" == "--boot" ]]; then
		if [[ "$PLATFORM" == "NixOS" ]]; then
			ACTION="boot"
		else
			echo "Warning: --boot flag is only supported on NixOS, ignoring..."
		fi
	elif [[ "$arg" == "--diff" || "$arg" == "--compare" ]]; then
		DIFF_MODE=true
	else
		EXTRA_ARGS+=("$arg")
	fi
done

# ── Locate existing Nix tools ──────────────────────────────────────
if [[ "$PLATFORM" == "Darwin" ]]; then
	# Fresh shells may not have loaded the profiles created by the installer.
	for profile_bin in /run/current-system/sw/bin /nix/var/nix/profiles/default/bin "$HOME/.nix-profile/bin"; do
		if [[ -d "$profile_bin" ]]; then
			export PATH="$PATH:$profile_bin"
		fi
	done
fi

# ── First-time nix-darwin setup ────────────────────────────────────
if [[ "$PLATFORM" == "Darwin" ]] && ! command -v darwin-rebuild &>/dev/null; then
	if [[ "$DIFF_MODE" == true ]]; then
		command -v nix &>/dev/null || {
			echo "Install Nix first; diff mode does not install or activate anything."
			exit 1
		}
		nix --extra-experimental-features 'nix-command flakes' run --inputs-from "$SCRIPT_DIR" nix-darwin -- build --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
		if [ -e "$CURRENT_SYSTEM" ] && command -v nvd &>/dev/null; then
			nvd diff "$CURRENT_SYSTEM" ./result
		else
			echo "Build complete at ./result; no running nix-darwin system/nvd available to compare."
		fi
		echo "No activation performed. Run ./rebuild.sh to apply after review."
		exit 0
	fi
	[ -t 0 ] || {
		echo "First-time setup requires an interactive terminal."
		exit 1
	}
	if ! command -v nix &>/dev/null; then
		echo "Nix was not found in PATH or its standard installation locations."
		echo "Setup can download and run the official installer from https://nixos.org/nix/install."
		echo "This installs the Nix daemon and may request administrator access."
		printf 'Install Nix now? [y/N] '
		if ! read -r REPLY; then
			REPLY=""
		fi
		case "$REPLY" in
		y | Y | yes | YES) ;;
		*)
			echo "Setup cancelled; Nix was not installed."
			exit 1
			;;
		esac

		INSTALLER="$(mktemp -t nix-install.XXXXXX)"
		if ! curl --proto '=https' --tlsv1.2 -fL https://nixos.org/nix/install -o "$INSTALLER"; then
			rm -f "$INSTALLER"
			echo "Could not download the Nix installer; setup stopped."
			exit 1
		fi
		if ! sh "$INSTALLER" --daemon; then
			rm -f "$INSTALLER"
			echo "Nix installation failed; setup stopped."
			exit 1
		fi
		rm -f "$INSTALLER"

		# The installer cannot update this process's environment.
		export PATH="$PATH:/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin"
		if ! command -v nix &>/dev/null; then
			echo "The installer finished, but nix is still unavailable. Open a new terminal and rerun ./rebuild.sh."
			exit 1
		fi
	fi

	echo "darwin-rebuild was not found in PATH."
	echo "First-time setup will build using this flake's pinned nix-darwin, then activate $HOST_NAME with sudo."
	echo "Review a build first with ./rebuild.sh --diff if you have not already done so."
	echo "If nix-darwin is already installed, cancel and load its shell environment instead."
	printf 'Install and activate nix-darwin now? [y/N] '
	if ! read -r REPLY; then
		REPLY=""
	fi
	case "$REPLY" in
	y | Y | yes | YES) ;;
	*)
		echo "Setup cancelled; no build or activation was performed."
		exit 1
		;;
	esac

	nix --extra-experimental-features 'nix-command flakes' run --inputs-from "$SCRIPT_DIR" nix-darwin -- build --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
	sudo ./result/sw/bin/darwin-rebuild switch --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
	echo "nix-darwin setup complete. Open a new terminal before running ./rebuild.sh again."
	exit 0
fi

# ── Diff Mode ──────────────────────────────────────────────────────
if [[ "$DIFF_MODE" == true ]]; then
	if [[ "$PLATFORM" == "Home-Manager" ]]; then
		echo "Diff mode is not supported for standalone home-manager hosts."
		exit 1
	fi

	echo "Building configuration for $CURRENT_HOSTNAME ($PLATFORM) to compare changes..."
	echo ""

	echo "-> Running build..."
	echo "   Command: $BASE_REBUILD_CMD build --flake \"$FLAKE_PATH\" ${EXTRA_ARGS[*]:-}"
	echo ""
	$BASE_REBUILD_CMD build --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
	BUILD_EXIT=$?

	if [[ $BUILD_EXIT -ne 0 ]]; then
		echo ""
		echo "Build failed! Cannot compare."
		exit $BUILD_EXIT
	fi

	echo ""
	echo "Build successful!"
	echo ""

	if ! command -v nvd &>/dev/null; then
		echo "nvd not found. Install it with: nix-shell -p nvd"
		echo ""
		echo "Falling back to nix store diff..."
		nix store diff-closures "$CURRENT_SYSTEM" ./result
	else
		echo "-> Comparing with current system using nvd..."
		echo ""
		nvd diff "$CURRENT_SYSTEM" ./result
	fi

	echo ""
	echo "To apply these changes, run: ./rebuild.sh"

# ── Home-Manager Switch ───────────────────────────────────────────
elif [[ "$PLATFORM" == "Home-Manager" ]]; then
	echo "Rebuilding $CURRENT_HOSTNAME ($PLATFORM using $FLAKE_PATH)..."
	if command -v home-manager &>/dev/null; then
		HOME_MANAGER_CMD=(home-manager)
	else
		if ! command -v nix &>/dev/null; then
			echo "Neither home-manager nor nix was found in PATH. Install Nix (or load its shell environment) first."
			exit 1
		fi
		echo "home-manager not found; bootstrapping with the flake's pinned Home Manager input..."
		HOME_MANAGER_CMD=(nix run --inputs-from "$SCRIPT_DIR" home-manager --)
	fi
	printf '   Command: '
	printf '%q ' "${HOME_MANAGER_CMD[@]}" switch --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
	echo ""
	echo ""
	"${HOME_MANAGER_CMD[@]}" switch --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}

# ── Normal Rebuild (NixOS / Darwin) ───────────────────────────────
else
	echo "Rebuilding $CURRENT_HOSTNAME ($PLATFORM using $FLAKE_PATH)..."

	if [[ "$NEEDS_SUDO" == true ]]; then
		echo "   Command: sudo $BASE_REBUILD_CMD $ACTION --flake \"$FLAKE_PATH\" ${EXTRA_ARGS[*]:-}"
		echo ""
		sudo $BASE_REBUILD_CMD $ACTION --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
	else
		echo "   Command: $BASE_REBUILD_CMD $ACTION --flake \"$FLAKE_PATH\" ${EXTRA_ARGS[*]:-}"
		echo ""
		$BASE_REBUILD_CMD $ACTION --flake "$FLAKE_PATH" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
	fi
fi

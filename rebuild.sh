#!/usr/bin/env bash

# Auto-detect host and rebuild configuration
# Usage: ./rebuild.sh [--boot] [--diff|--compare] [additional args...]
#
# Hosts are discovered automatically from hosts/*/meta.nix files.
# No manual edits needed when adding new hosts.

set -euo pipefail

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
  echo "Unknown host: $CURRENT_HOSTNAME"
  echo ""
  echo "No hosts/*/meta.nix matched hostname \"$CURRENT_HOSTNAME\"."
  echo ""
  echo "Available hosts:"
  for meta_file in "$SCRIPT_DIR"/hosts/*/meta.nix; do
    [ -f "$meta_file" ] || continue
    local_name="$(basename "$(dirname "$meta_file")")"
    local_hostname="$(sed -n 's/.*hostname *= *"\([^"]*\)".*/\1/p' "$meta_file" | head -1)"
    local_type="$(sed -n 's/.*type *= *"\([^"]*\)".*/\1/p' "$meta_file" | head -1)"
    echo "  $local_name ($local_type) -> hostname: $local_hostname"
  done
  exit 1
fi

# Derive rebuild command and flake path from host type
case "$HOST_TYPE" in
  "nixos")
    FLAKE_PATH="$SCRIPT_DIR#$HOST_NAME"
    BASE_REBUILD_CMD="nixos-rebuild"
    NEEDS_SUDO=true
    PLATFORM="NixOS"
    CURRENT_SYSTEM="/run/current-system"
    ;;
  "darwin")
    FLAKE_PATH="$SCRIPT_DIR#$HOST_NAME"
    BASE_REBUILD_CMD="darwin-rebuild"
    NEEDS_SUDO=true
    PLATFORM="Darwin"
    CURRENT_SYSTEM="/run/current-system"
    ;;
  "home-manager")
    FLAKE_PATH="$SCRIPT_DIR#${HOST_USERNAME}@${HOST_NAME}"
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
DIFF_MODE=false
EXTRA_ARGS=()

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
  $BASE_REBUILD_CMD build --flake "$FLAKE_PATH" "${EXTRA_ARGS[@]}"
  BUILD_EXIT=$?

  if [[ $BUILD_EXIT -ne 0 ]]; then
    echo ""
    echo "Build failed! Cannot compare."
    exit $BUILD_EXIT
  fi

  echo ""
  echo "Build successful!"
  echo ""

  if ! command -v nvd &> /dev/null; then
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
  echo "   Command: home-manager switch --flake \"$FLAKE_PATH\" ${EXTRA_ARGS[*]:-}"
  echo ""
  home-manager switch --flake "$FLAKE_PATH" "${EXTRA_ARGS[@]}"

# ── Normal Rebuild (NixOS / Darwin) ───────────────────────────────
else
  echo "Rebuilding $CURRENT_HOSTNAME ($PLATFORM using $FLAKE_PATH)..."

  if [[ "$NEEDS_SUDO" == true ]]; then
    echo "   Command: sudo $BASE_REBUILD_CMD $ACTION --flake \"$FLAKE_PATH\" ${EXTRA_ARGS[*]:-}"
    echo ""
    sudo $BASE_REBUILD_CMD $ACTION --flake "$FLAKE_PATH" "${EXTRA_ARGS[@]}"
  else
    echo "   Command: $BASE_REBUILD_CMD $ACTION --flake \"$FLAKE_PATH\" ${EXTRA_ARGS[*]:-}"
    echo ""
    $BASE_REBUILD_CMD $ACTION --flake "$FLAKE_PATH" "${EXTRA_ARGS[@]}"
  fi
fi

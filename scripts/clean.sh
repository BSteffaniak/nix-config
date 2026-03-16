#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DISPLAY_PATH="./scripts/$SCRIPT_NAME"

DELETE_MODE="older-than"
OLDER_THAN="14d"
USE_SUDO=true
ASSUME_YES=false

usage() {
  cat <<EOF
Usage: $DISPLAY_PATH [OPTIONS]

Clean unused Nix packages and optimize the store.

Options:
  -o, --older-than <duration>  Delete generations older than duration (default: 14d)
  -d, --delete-all-old         Delete all old generations (aggressive)
      --no-sudo                Skip system cleanup and store optimization
  -y, --yes                    Skip confirmation prompt
  -h, --help                   Show this help message

Examples:
  $DISPLAY_PATH
  $DISPLAY_PATH --older-than 30d
  $DISPLAY_PATH --delete-all-old
  $DISPLAY_PATH --delete-all-old --no-sudo
EOF
}

prompt_confirm() {
  local answer
  read -rp "Proceed? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--older-than)
      if [[ $# -lt 2 ]]; then
        echo "Error: missing value for $1" >&2
        usage
        exit 1
      fi
      DELETE_MODE="older-than"
      OLDER_THAN="$2"
      shift 2
      ;;
    -d|--delete-all-old)
      DELETE_MODE="all"
      shift
      ;;
    --no-sudo)
      USE_SUDO=false
      shift
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$DELETE_MODE" == "all" ]]; then
  GC_ARGS=("-d")
  GC_LABEL="delete all old generations"
else
  GC_ARGS=("--delete-older-than" "$OLDER_THAN")
  GC_LABEL="delete generations older than $OLDER_THAN"
fi

echo "Nix cleanup plan:"
echo "- User profiles: nix-collect-garbage ${GC_ARGS[*]}"
if [[ "$USE_SUDO" == true ]]; then
  echo "- System profiles: sudo nix-collect-garbage ${GC_ARGS[*]}"
  echo "- Store optimize: sudo nix-store --optimise"
else
  echo "- System cleanup skipped (--no-sudo)"
fi

if [[ "$ASSUME_YES" == false ]]; then
  if ! prompt_confirm; then
    echo "Cancelled."
    exit 0
  fi
fi

echo
echo "[1/3] Running user cleanup (${GC_LABEL})..."
nix-collect-garbage "${GC_ARGS[@]}"

if [[ "$USE_SUDO" == true ]]; then
  if command -v sudo >/dev/null 2>&1; then
    echo
    echo "[2/3] Running system cleanup (${GC_LABEL})..."
    sudo nix-collect-garbage "${GC_ARGS[@]}"

    echo
    echo "[3/3] Optimizing Nix store..."
    sudo nix-store --optimise
  else
    echo
    echo "Warning: sudo not found; skipping system cleanup and optimization." >&2
  fi
else
  echo
  echo "[2/3] Skipped system cleanup."
  echo "[3/3] Skipped store optimization."
fi

echo
echo "Done."

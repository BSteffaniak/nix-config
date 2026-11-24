#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DISPLAY_PATH="./scripts/$SCRIPT_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_FLAKE=true
RUN_SOURCE=true
RUN_GITHUB=true
RUN_ANTIGRAVITY=true
ASSUME_YES=false

usage() {
	cat <<EOF
Usage: $DISPLAY_PATH [OPTIONS]

Update everything in one run:
  1. flake inputs
  2. source-build hashes
  3. GitHub release versions
  4. Antigravity CLI version

Options:
      --no-flake     Skip 'nix flake update'
      --no-source    Skip source-build hash updates
      --no-github    Skip GitHub release updates
      --no-antigravity  Skip Antigravity CLI update
  -y, --yes          Skip confirmation prompt
  -h, --help         Show this help message

Examples:
  $DISPLAY_PATH
  $DISPLAY_PATH --yes
  $DISPLAY_PATH --no-github
EOF
}

prompt_confirm() {
	local answer
	read -rp "Proceed? [y/N]: " answer
	[[ "$answer" =~ ^[Yy]$ ]]
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--no-flake)
		RUN_FLAKE=false
		shift
		;;
	--no-source)
		RUN_SOURCE=false
		shift
		;;
	--no-github)
		RUN_GITHUB=false
		shift
		;;
	--no-antigravity)
		RUN_ANTIGRAVITY=false
		shift
		;;
	-y | --yes)
		ASSUME_YES=true
		shift
		;;
	-h | --help)
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

if [[ "$RUN_FLAKE" == false && "$RUN_SOURCE" == false && "$RUN_GITHUB" == false && "$RUN_ANTIGRAVITY" == false ]]; then
	echo "Error: nothing to do (all update steps are disabled)." >&2
	echo "Use '$DISPLAY_PATH --help' for options." >&2
	exit 1
fi

echo "Update plan:"
if [[ "$RUN_FLAKE" == true ]]; then
	echo "- Flake inputs: nix flake update"
else
	echo "- Flake inputs: skipped (--no-flake)"
fi

if [[ "$RUN_SOURCE" == true ]]; then
	echo "- Source builds: ./scripts/source-build.sh update --all"
else
	echo "- Source builds: skipped (--no-source)"
fi

if [[ "$RUN_GITHUB" == true ]]; then
	echo "- GitHub releases: ./scripts/github-release.sh update --all"
else
	echo "- GitHub releases: skipped (--no-github)"
fi

if [[ "$RUN_ANTIGRAVITY" == true ]]; then
	echo "- Antigravity CLI: ./scripts/antigravity-cli.sh update"
else
	echo "- Antigravity CLI: skipped (--no-antigravity)"
fi

if [[ "$ASSUME_YES" == false ]]; then
	if ! prompt_confirm; then
		echo "Cancelled."
		exit 0
	fi
fi

echo
if [[ "$RUN_FLAKE" == true ]]; then
	echo "[1/4] Updating flake inputs..."
	nix flake update --flake "$REPO_ROOT"
else
	echo "[1/4] Skipped flake input update."
fi

echo
if [[ "$RUN_SOURCE" == true ]]; then
	echo "[2/4] Updating source-build hashes..."
	"$REPO_ROOT/scripts/source-build.sh" update --all
else
	echo "[2/4] Skipped source-build hash updates."
fi

echo
if [[ "$RUN_GITHUB" == true ]]; then
	echo "[3/4] Updating GitHub release versions..."
	"$REPO_ROOT/scripts/github-release.sh" update --all
else
	echo "[3/4] Skipped GitHub release updates."
fi

echo
if [[ "$RUN_ANTIGRAVITY" == true ]]; then
	echo "[4/4] Updating Antigravity CLI version..."
	"$REPO_ROOT/scripts/antigravity-cli.sh" update
else
	echo "[4/4] Skipped Antigravity CLI update."
fi

echo
echo "Done. Changed files:"
git -C "$REPO_ROOT" status --short

#!/usr/bin/env bash
# antigravity-cli.sh - Track the latest Google Antigravity CLI (agy) release
#
# Google doesn't publish the CLI on GitHub. Its installer reads one JSON
# manifest per platform from an auto-updater service:
#   { "version": "...", "url": "https://storage.googleapis.com/...", "sha512": "<hex>" }
# This script reads the same manifests and writes
# pkgs/antigravity-cli/version.json, which overlays/antigravity-cli.nix
# consumes. Nothing is downloaded; the manifests carry the hashes.
#
# Usage:
#   ./scripts/antigravity-cli.sh check     # Report whether an update is available
#   ./scripts/antigravity-cli.sh update    # Write version.json if a new version exists
#   ./scripts/antigravity-cli.sh update --force   # Rewrite even if the version is unchanged
#
# Requires: curl, jq, nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$REPO_ROOT/pkgs/antigravity-cli/version.json"
MANIFEST_BASE="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests"

# Nix system -> manifest platform name (as used by Google's install.sh)
# (bash 3.2-compatible: "<system>:<manifest platform>")
PLATFORMS=(
	aarch64-darwin:darwin_arm64
	x86_64-linux:linux_amd64
	aarch64-linux:linux_arm64
)

if [ -t 1 ]; then
	RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;34m' NC='\033[0m'
else
	RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi
info() { echo -e "${BLUE}[info]${NC} $*"; }
ok() { echo -e "${GREEN}[ok]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
err() { echo -e "${RED}[error]${NC} $*" >&2; }

for cmd in curl jq nix; do
	if ! command -v "$cmd" &>/dev/null; then
		err "Required command '$cmd' not found."
		exit 1
	fi
done

usage() {
	sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

current_version() {
	if [ -f "$VERSION_FILE" ]; then
		jq -r '.version' "$VERSION_FILE"
	else
		echo "none"
	fi
}

# Fetch all manifests into a single JSON object keyed by Nix system.
# Fails if any manifest is missing fields or platforms disagree on version.
fetch_manifests() {
	local combined='{}' entry system platform manifest
	for entry in "${PLATFORMS[@]}"; do
		system="${entry%%:*}"
		platform="${entry#*:}"
		manifest="$(curl -fsSL "$MANIFEST_BASE/$platform.json")" || {
			err "Failed to fetch manifest for $system ($platform)"
			return 1
		}
		if ! jq -e '.version and .url and .sha512' >/dev/null <<<"$manifest"; then
			err "Manifest for $system is missing version/url/sha512:"
			echo "$manifest" >&2
			return 1
		fi
		combined="$(jq --arg s "$system" --argjson m "$manifest" '.[$s] = $m' <<<"$combined")"
	done

	local versions
	versions="$(jq -r '[.[].version] | unique | join(", ")' <<<"$combined")"
	if [ "$(jq '[.[].version] | unique | length' <<<"$combined")" -ne 1 ]; then
		err "Platforms disagree on the latest version ($versions); Google may be mid-rollout. Try again later."
		return 1
	fi
	echo "$combined"
}

cmd_check() {
	local manifests latest current
	manifests="$(fetch_manifests)"
	latest="$(jq -r 'first(.[].version)' <<<"$manifests")"
	current="$(current_version)"
	if [ "$latest" = "$current" ]; then
		ok "antigravity-cli is up to date ($current)"
	else
		info "antigravity-cli: $current -> $latest"
		info "Run: ./scripts/antigravity-cli.sh update"
	fi
}

cmd_update() {
	local force="${1:-false}"
	local manifests latest current
	manifests="$(fetch_manifests)"
	latest="$(jq -r 'first(.[].version)' <<<"$manifests")"
	current="$(current_version)"

	if [ "$latest" = "$current" ] && [ "$force" != true ]; then
		ok "antigravity-cli is up to date ($current)"
		return 0
	fi

	local platforms='{}' entry system url hash build_id="" this_build
	for entry in "${PLATFORMS[@]}"; do
		system="${entry%%:*}"
		url="$(jq -r --arg s "$system" '.[$s].url' <<<"$manifests")"
		hash="$(nix hash convert --hash-algo sha512 --to sri "$(jq -r --arg s "$system" '.[$s].sha512' <<<"$manifests")")"
		# URL path: .../antigravity-cli/<version>-<buildId>/<platform>/<file>
		this_build="$(sed -nE "s#.*/antigravity-cli/${latest//./\\.}-([0-9]+)/.*#\1#p" <<<"$url")"
		if [ -z "$this_build" ]; then
			err "Could not parse build id from URL for $system: $url"
			return 1
		fi
		if [ -n "$build_id" ] && [ "$build_id" != "$this_build" ]; then
			err "Platforms disagree on build id ($build_id vs $this_build)"
			return 1
		fi
		build_id="$this_build"
		platforms="$(jq --arg s "$system" --arg u "$url" --arg h "$hash" '.[$s] = {url: $u, hash: $h}' <<<"$platforms")"
	done

	mkdir -p "$(dirname "$VERSION_FILE")"
	jq -n --arg v "$latest" --arg b "$build_id" --argjson p "$platforms" \
		'{version: $v, buildId: $b, platforms: ($p | to_entries | sort_by(.key) | from_entries)}' \
		>"$VERSION_FILE"
	ok "antigravity-cli: $current -> $latest (build $build_id)"
}

main() {
	case "${1:-}" in
	check) cmd_check ;;
	update)
		if [ "${2:-}" = "--force" ]; then cmd_update true; else cmd_update; fi
		;;
	-h | --help | help | "") usage ;;
	*)
		err "Unknown command '$1'"
		usage
		exit 1
		;;
	esac
}

main "$@"

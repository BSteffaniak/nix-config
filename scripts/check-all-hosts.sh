#!/usr/bin/env bash

# Evaluate every host configuration and compare derivation paths against a
# saved baseline. Used as a zero-diff regression gate during refactors.
#
# Usage:
#   ./scripts/check-all-hosts.sh save [file]     Evaluate and write baseline
#   ./scripts/check-all-hosts.sh compare [file]  Evaluate and diff against baseline
#   ./scripts/check-all-hosts.sh eval            Evaluate and print drvPaths only
#
# Baseline file defaults to .host-drvs.baseline (gitignored).
#
# Hosts are discovered from hosts/*/meta.nix, matching flake.nix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MODE="${1:-compare}"
BASELINE="${2:-$REPO_DIR/.host-drvs.baseline}"

cd "$REPO_DIR"

attr_for_host() {
	local meta_file="$1"
	local name type username
	name="$(basename "$(dirname "$meta_file")")"
	type="$(sed -n 's/.*type *= *"\([^"]*\)".*/\1/p' "$meta_file" | head -1)"
	username="$(sed -n 's/.*username *= *"\([^"]*\)".*/\1/p' "$meta_file" | head -1)"

	case "$type" in
	nixos) echo "nixosConfigurations.$name.config.system.build.toplevel.drvPath" ;;
	darwin) echo "darwinConfigurations.$name.config.system.build.toplevel.drvPath" ;;
	home-manager) echo "homeConfigurations.\"$username@$name\".activationPackage.drvPath" ;;
	*)
		echo "Unknown host type '$type' in $meta_file" >&2
		return 1
		;;
	esac
}

evaluate_all() {
	local meta_file attr drv
	# `path:` makes nix read the working tree directly, so untracked files are
	# visible during refactors without staging them first.
	for meta_file in hosts/*/meta.nix; do
		attr="$(attr_for_host "$meta_file")"
		drv="$(nix eval --raw "path:$REPO_DIR#$attr")"
		printf '%s\t%s\n' "$attr" "$drv"
	done
}

case "$MODE" in
eval)
	evaluate_all
	;;
save)
	evaluate_all >"$BASELINE"
	echo "Saved baseline to $BASELINE"
	cat "$BASELINE"
	;;
compare)
	if [ ! -f "$BASELINE" ]; then
		echo "No baseline at $BASELINE. Run: $0 save" >&2
		exit 1
	fi
	CURRENT="$(mktemp)"
	trap 'rm -f "$CURRENT"' EXIT
	evaluate_all >"$CURRENT"
	if diff -u "$BASELINE" "$CURRENT"; then
		echo "All hosts match baseline."
	else
		echo ""
		echo "Derivations differ from baseline. Inspect with:"
		echo "  nix-diff <old-drv> <new-drv>"
		exit 1
	fi
	;;
*)
	echo "Usage: $0 {save|compare|eval} [baseline-file]" >&2
	exit 1
	;;
esac

#!/usr/bin/env bash
# Validate configs/bcode-git/config.toml against bcode git's settings schema.
#
# Usage: scripts/check-bcode-git-config.sh [BCODE_GIT]
#   BCODE_GIT  bcode-git binary to validate with (default: $BCODE_GIT, then bcode-git on PATH).
#              Use one built from the bcode checkout whose schema you run.
#
# The file is checked in isolation: no user, repository or environment configuration is read.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${repo_root}/configs/bcode-git/config.toml"
bcode_git="${1:-${BCODE_GIT:-bcode-git}}"

if ! command -v "${bcode_git}" >/dev/null 2>&1; then
	echo "error: ${bcode_git} not found; pass the binary path or set BCODE_GIT" >&2
	exit 2
fi

scratch="$(mktemp -d)"
trap 'rm -rf "${scratch}"' EXIT

report="$(
	cd "${scratch}" &&
		env -u BCODE_CONFIG -u BCODE_CONFIG_TOML -u BCODE_GIT_CONFIG -u BCODE_GIT_CONFIG_TOML \
			XDG_CONFIG_HOME="${scratch}/config" \
			"${bcode_git}" -C "${scratch}" --config "${config_file}" --print-config-paths
)"

if grep -q '^problem:' <<<"${report}"; then
	echo "${config_file} has problems:" >&2
	grep '^problem:' <<<"${report}" >&2
	exit 1
fi
echo "ok: ${config_file}"

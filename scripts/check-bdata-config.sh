#!/usr/bin/env bash
# Validate configs/bdata/config.toml with `bdata config check`.
#
# Usage: scripts/check-bdata-config.sh [BDATA]
#   BDATA  bdata binary to validate with (default: $BDATA, then bdata on PATH).
#          Use one built from the bdata checkout whose settings you run.
#
# The file is checked in isolation: no user, project or environment configuration is read.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${repo_root}/configs/bdata/config.toml"
bdata="${1:-${BDATA:-bdata}}"

if ! command -v "${bdata}" >/dev/null 2>&1; then
	echo "error: ${bdata} not found; pass the binary path or set BDATA" >&2
	exit 2
fi

scratch="$(mktemp -d)"
trap 'rm -rf "${scratch}"' EXIT
mkdir -p "${scratch}/config" "${scratch}/state"
cp "${config_file}" "${scratch}/config/config.toml"

if (
	cd "${scratch}" &&
		env -u BDATA_CONFIG -u BDATA_CONFIG_TOML -u BDATA_PROFILE \
			BDATA_CONFIG_DIR="${scratch}/config" BDATA_STATE_DIR="${scratch}/state" \
			"${bdata}" config check
); then
	echo "ok: ${config_file}"
else
	echo "${config_file} has problems (above)" >&2
	exit 1
fi

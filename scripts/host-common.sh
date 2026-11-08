#!/usr/bin/env bash
# Shared, Nix-independent host inventory and input validation (Bash 3.2).
meta_field() {
	sed -n "s/^[[:space:]]*$2 *= *\"\([^\"]*\)\".*/\1/p" "$1" | head -1
}

valid_host_name() {
	[[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] && [ "${#1}" -le 63 ]
}

# Escape a literal for a Nix double-quoted string, including interpolation.
nix_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//\$\{/\\\$\{}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	printf '%s' "$value"
}

machine_type() {
	case "$(uname -s)" in
	Darwin) echo darwin ;;
	Linux) if [ -e /etc/NIXOS ]; then echo nixos; else echo home-manager; fi ;;
	*) return 1 ;;
	esac
}

machine_system() {
	local arch
	arch="$(uname -m)"
	case "$arch" in arm64) arch=aarch64 ;; esac
	case "$(uname -s)" in
	Darwin) printf '%s-darwin\n' "$arch" ;;
	Linux) printf '%s-linux\n' "$arch" ;;
	*) return 1 ;;
	esac
}

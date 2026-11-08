#!/usr/bin/env bash
# Sourced by rebuild.sh only when automatic hostname discovery fails.
recover_unknown_host() {
	local meta name type system choice selected target local_name
	echo "Unknown host: $CURRENT_HOSTNAME"
	echo "Available hosts (directory -> system hostname, account, platform):"
	for meta in "$SCRIPT_DIR"/hosts/*/meta.nix; do
		[ -f "$meta" ] || continue
		printf '  %s -> %s, %s, %s\n' "$(basename "$(dirname "$meta")")" \
			"$(meta_field "$meta" hostname)" "$(meta_field "$meta" username)" "$(meta_field "$meta" system)"
	done
	echo "Use bootstrap.sh to create a new host, or select an existing compatible host below."
	if [ ! -t 0 ] || [ "$PREFLIGHT_DIFF" = true ]; then
		echo "No changes made. For hostname setup, run ./rebuild.sh interactively without --diff/--compare."
		return 1
	fi
	printf 'Enter an existing host directory name, "new" to bootstrap, or blank to cancel: '
	read -r choice || return 1
	[ -n "$choice" ] || return 1
	if [ "$choice" = new ]; then
		bash "$SCRIPT_DIR/bootstrap.sh" || return 1
		echo "Review the generated configuration, then rerun ./rebuild.sh. No activation performed."
		return 1
	fi
	valid_host_name "$choice" || {
		echo "Invalid host name"
		return 1
	}
	selected="$SCRIPT_DIR/hosts/$choice/meta.nix"
	[ -f "$selected" ] || {
		echo "No such host"
		return 1
	}
	type="$(meta_field "$selected" type)"
	system="$(meta_field "$selected" system)"
	if [ "$type" != "$(machine_type)" ] || [ "$system" != "$(machine_system)" ]; then
		echo "Selected host is incompatible with this machine's platform/architecture."
		return 1
	fi
	HOST_USERNAME="$(meta_field "$selected" username)"
	id "$HOST_USERNAME" >/dev/null 2>&1 || {
		echo "Required account '$HOST_USERNAME' does not exist; create it first."
		return 1
	}
	target="$(meta_field "$selected" hostname)"
	valid_host_name "$target" || {
		echo "Configured hostname is not a valid DNS label; change it manually."
		return 1
	}
	echo "Selected $choice for account $HOST_USERNAME. System hostname: $CURRENT_HOSTNAME -> $target"
	if [ "$type" = darwin ]; then
		echo "Bonjour name: $(scutil --get LocalHostName 2>/dev/null || true) -> $choice"
		echo "Display ComputerName will remain unchanged."
	fi
	[ -z "${SSH_CONNECTION:-}" ] || echo "Warning: renaming over SSH may affect future connections."
	printf 'Rename this machine? [y/N] '
	read -r choice || return 1
	case "$choice" in y | Y | yes) ;; *) return 1 ;; esac
	case "$type" in
	darwin)
		sudo scutil --set HostName "$target" || return 1
		local_name="$(basename "$(dirname "$selected")")"
		sudo scutil --set LocalHostName "$local_name" || return 1
		;;
	*) sudo hostnamectl set-hostname "$target" || return 1 ;;
	esac
	CURRENT_HOSTNAME="$(hostname)"
	discover_host "$CURRENT_HOSTNAME" || {
		echo "Hostname still does not match; inspect it before retrying."
		return 1
	}
	echo "Hostname configured. Building a diff only; rerun ./rebuild.sh after reviewing it to activate."
	FORCE_DIFF=true
}

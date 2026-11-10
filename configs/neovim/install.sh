#!/usr/bin/env bash
# Explicit plugin maintenance only. Never invoked by normal editor startup.
set -euo pipefail
mode="${1:-restore}"
case "$mode" in
restore | update) ;;
*)
	echo "Usage: $0 [restore|update]" >&2
	exit 1
	;;
esac
for tool in git nvim python3; do
	command -v "$tool" >/dev/null || {
		echo "Missing prerequisite: $tool" >&2
		exit 1
	}
done
config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
state="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
seed="$config/lazy-lock.json"
mkdir -p "$data/lazy" "$state"
if [[ ! -d "$data/lazy/lazy.nvim" ]]; then
	commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["lazy.nvim"]["commit"])' "$seed")"
	GIT_TERMINAL_PROMPT=0 git clone --filter=blob:none https://github.com/folke/lazy.nvim.git "$data/lazy/lazy.nvim"
	GIT_TERMINAL_PROMPT=0 git -C "$data/lazy/lazy.nvim" checkout --detach "$commit"
fi
if [[ "$mode" == restore ]]; then
	cp "$seed" "$state/lazy-lock.json"
	chmod u+w "$state/lazy-lock.json"
	nvim --headless '+lua require("lazy").install({wait=true,lockfile=true})' '+Lazy! restore' +qa
else
	nvim --headless '+Lazy! update' +qa
fi
# Review and copy this writable lock to configs/neovim/lazy-lock.json to pin an update.
echo "Plugin lock: $state/lazy-lock.json"

#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/BSteffaniak/nix-config.git"
CONFIG_NAME="$1"
DEST="${2:-$HOME/.config/$CONFIG_NAME}"
DEST="$(realpath -m "$DEST")"

usage() {
  echo "Usage: $0 <config-name> [destination]"
  echo ""
  echo "Available configs:"
  echo "  neovim, hyprland, waybar, ghostty, tmux, wezterm, zellij,"
  echo "  lazygit, bottom, gh, opencode, lspmux, fuzzel,"
  echo "  waypaper, act, htop"
  echo ""
  echo "Examples:"
  echo "  $0 neovim"
  echo "  $0 tmux ~/.tmux"
  echo ""
  echo "Or install directly from GitHub:"
  echo "  curl -fsSL https://raw.githubusercontent.com/BSteffaniak/nix-config/master/install-config.sh | bash -s neovim"
  exit 1
}

if [ -z "$CONFIG_NAME" ]; then
  usage
fi

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "→ Cloning $CONFIG_NAME config from $REPO_URL..."
git clone --filter=blob:none --sparse "$REPO_URL" "$TMP_DIR"
cd "$TMP_DIR"
git sparse-checkout set "configs/$CONFIG_NAME"

if [ ! -d "configs/$CONFIG_NAME" ]; then
  echo "Error: Config '$CONFIG_NAME' not found in repository"
  exit 1
fi

echo "→ Installing to $DEST..."
if [ -d "$DEST" ] || [ -f "$DEST" ]; then
  BACKUP="$DEST.backup.$(date +%s)"
  echo "  Backing up existing config to $BACKUP"
  mv "$DEST" "$BACKUP"
fi

mkdir -p "$(dirname "$DEST")"
cp -r "configs/$CONFIG_NAME/." "$DEST"

# Make scripts executable if present
if [ -d "$DEST/scripts" ]; then
  chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true
fi

# Make individual scripts executable
find "$DEST" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "✓ $CONFIG_NAME installed to $DEST"

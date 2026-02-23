#!/usr/bin/env bash

# Initialize git-crypt for this repository
# Run this once after cloning on a new machine.
#
# Prerequisites:
#   - git-crypt: nix-shell -p git-crypt  (or install via your package manager)
#   - GPG key:   gpg --gen-key           (if you don't have one)
#
# Usage:
#   First time setup (creates symmetric key):
#     ./scripts/setup-git-crypt.sh init
#
#   Add a GPG user who can unlock (run on a machine that already has the key):
#     ./scripts/setup-git-crypt.sh add-user <GPG_KEY_ID>
#
#   Unlock on a new machine (if your GPG key is available):
#     ./scripts/setup-git-crypt.sh unlock
#
#   Export symmetric key for sharing via secure channel (e.g., Tailscale):
#     ./scripts/setup-git-crypt.sh export-key <output-file>
#
#   Import symmetric key on a new machine:
#     ./scripts/setup-git-crypt.sh import-key <key-file>

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if ! command -v git-crypt &> /dev/null; then
  echo "git-crypt not found."
  echo "Install it with: nix-shell -p git-crypt"
  echo "Or add it to your nix configuration."
  exit 1
fi

case "${1:-help}" in
  init)
    echo "Initializing git-crypt..."
    cd "$REPO_DIR"
    git-crypt init
    echo ""
    echo "git-crypt initialized. Encrypted paths are defined in .gitattributes."
    echo ""
    echo "Next steps:"
    echo "  1. Add your GPG key:  ./scripts/setup-git-crypt.sh add-user <YOUR_GPG_KEY_ID>"
    echo "  2. Commit the changes: git add .gitattributes .git-crypt/ && git commit -m 'Initialize git-crypt'"
    echo "  3. Push to remote -- encrypted files will appear as binary blobs on GitHub"
    ;;

  add-user)
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 add-user <GPG_KEY_ID>"
      echo ""
      echo "List your GPG keys with: gpg --list-keys"
      exit 1
    fi
    cd "$REPO_DIR"
    git-crypt add-gpg-user "$2"
    echo "Added GPG user $2. They can now unlock the repo with: git-crypt unlock"
    ;;

  unlock)
    cd "$REPO_DIR"
    git-crypt unlock
    echo "Repository unlocked. Encrypted files are now readable."
    ;;

  export-key)
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 export-key <output-file>"
      echo "Share this file securely (e.g., via Tailscale, airdrop, USB)."
      exit 1
    fi
    cd "$REPO_DIR"
    git-crypt export-key "$2"
    echo "Symmetric key exported to $2"
    echo "Share this file securely. Anyone with this file can decrypt the repo."
    ;;

  import-key)
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 import-key <key-file>"
      exit 1
    fi
    cd "$REPO_DIR"
    git-crypt unlock "$2"
    echo "Repository unlocked using imported key."
    ;;

  status)
    cd "$REPO_DIR"
    git-crypt status
    ;;

  help|*)
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  init              Initialize git-crypt in this repo (first time only)"
    echo "  add-user <KEY_ID> Add a GPG user who can unlock the repo"
    echo "  unlock            Unlock the repo using your GPG key"
    echo "  export-key <file> Export the symmetric key for sharing"
    echo "  import-key <file> Unlock using an exported symmetric key"
    echo "  status            Show encryption status of files"
    ;;
esac

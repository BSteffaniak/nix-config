#!/usr/bin/env bash
# source-build.sh - Manage dependency hashes for source-built Nix packages
#
# Interactive mode (main menu):
#   ./scripts/source-build.sh
#
# Subcommands:
#   ./scripts/source-build.sh update                  # Interactive: pick packages
#   ./scripts/source-build.sh update --all            # Non-interactive: update all
#   ./scripts/source-build.sh update cronstrue        # Non-interactive: update one
#   ./scripts/source-build.sh update cronstrue --refresh  # Fetch latest + update
#   ./scripts/source-build.sh list                    # List packages + stale status
#   ./scripts/source-build.sh check                   # Check which are stale
#   ./scripts/source-build.sh add                     # Interactive wizard
#   ./scripts/source-build.sh remove                  # Interactive remove
#   ./scripts/source-build.sh remove <name>           # Non-interactive remove
#
# Requires: curl, jq, nix
# Uses: prefetch-npm-deps (for npm), nix build (for Rust cargoHash)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$REPO_ROOT/lib/source-builds/configs"
HASHES_DIR="$REPO_ROOT/lib/source-builds/hashes"
FLAKE_LOCK="$REPO_ROOT/flake.lock"

# ── Colors ──────────────────────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

info()    { echo -e "${BLUE}[info]${NC} $*"; }
ok()      { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
err()     { echo -e "${RED}[error]${NC} $*" >&2; }
header()  { echo -e "\n${BLUE}=== $* ===${NC}\n"; }
success() { echo -e "${GREEN}✓${NC} $*"; }

# ── Dependencies ────────────────────────────────────────────────────
for cmd in jq nix; do
  if ! command -v "$cmd" &>/dev/null; then
    err "Required command '$cmd' not found."
    exit 1
  fi
done

mkdir -p "$CONFIGS_DIR" "$HASHES_DIR"

# ── Helpers ─────────────────────────────────────────────────────────
prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local result
  if [ -n "$default" ]; then
    read -rp "$prompt [$default]: " result
    echo "${result:-$default}"
  else
    read -rp "$prompt: " result
    echo "$result"
  fi
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local result
  if [ "$default" = "y" ]; then
    read -rp "$prompt [Y/n]: " result
    result="${result:-y}"
  else
    read -rp "$prompt [y/N]: " result
    result="${result:-n}"
  fi
  [[ "$result" =~ ^[Yy] ]]
}

get_projects() {
  local projects=()
  for config_file in "$CONFIGS_DIR"/*.json; do
    [ -f "$config_file" ] || continue
    projects+=("$(basename "$config_file" .json)")
  done
  echo "${projects[@]}"
}

# Get the locked rev for a flake input from flake.lock
get_locked_rev() {
  local input_name="$1"
  jq -r ".nodes[\"$input_name\"].locked.rev // empty" "$FLAKE_LOCK"
}

# Get the nix store path for a flake input
get_input_store_path() {
  local input_name="$1"
  nix eval ".#darwinConfigurations" --apply "x: \"dummy\"" >/dev/null 2>&1 || true
  # Use nix flake archive to get the store path
  local path
  path=$(nix eval --raw ".inputs.$input_name.outPath" 2>/dev/null) || {
    # Fallback: reconstruct from flake.lock info
    local input_type rev narHash
    input_type=$(jq -r ".nodes[\"$input_name\"].locked.type // empty" "$FLAKE_LOCK")
    rev=$(jq -r ".nodes[\"$input_name\"].locked.rev // empty" "$FLAKE_LOCK")
    narHash=$(jq -r ".nodes[\"$input_name\"].locked.narHash // empty" "$FLAKE_LOCK")

    if [ "$input_type" = "github" ]; then
      local owner repo
      owner=$(jq -r ".nodes[\"$input_name\"].locked.owner // empty" "$FLAKE_LOCK")
      repo=$(jq -r ".nodes[\"$input_name\"].locked.repo // empty" "$FLAKE_LOCK")
      path=$(nix eval --raw --impure --expr "(builtins.fetchTree { type = \"github\"; owner = \"$owner\"; repo = \"$repo\"; rev = \"$rev\"; narHash = \"$narHash\"; }).outPath" 2>/dev/null)
    elif [ "$input_type" = "git" ]; then
      local url
      url=$(jq -r ".nodes[\"$input_name\"].locked.url // .nodes[\"$input_name\"].original.url // empty" "$FLAKE_LOCK")
      path=$(nix eval --raw --impure --expr "(builtins.fetchTree { type = \"git\"; url = \"$url\"; rev = \"$rev\"; narHash = \"$narHash\"; }).outPath" 2>/dev/null)
    fi

    if [ -z "${path:-}" ]; then
      err "Could not resolve store path for input '$input_name' (type: ${input_type:-unknown})"
      return 1
    fi
  }
  echo "$path"
}

# ── npm hash computation ────────────────────────────────────────────
compute_npm_hash() {
  local project="$1"
  local config_file="$CONFIGS_DIR/$project.json"
  local flake_input
  flake_input=$(jq -r '.flakeInput' "$config_file")

  info "Computing npmDepsHash for ${BOLD}$project${NC}..." >&2

  local store_path
  store_path=$(get_input_store_path "$flake_input") || return 1

  if [ ! -f "$store_path/package-lock.json" ]; then
    err "No package-lock.json found in $store_path"
    return 1
  fi

  local hash
  # Try prefetch-npm-deps first (fast, single download)
  if command -v prefetch-npm-deps &>/dev/null; then
    info "Using prefetch-npm-deps..." >&2
    hash=$(prefetch-npm-deps "$store_path/package-lock.json" 2>/dev/null) || {
      err "prefetch-npm-deps failed"
      return 1
    }
  else
    # Fall back to running it via nix shell
    info "Using nix shell for prefetch-npm-deps..." >&2
    hash=$(nix shell nixpkgs#prefetch-npm-deps -c prefetch-npm-deps "$store_path/package-lock.json" 2>/dev/null) || {
      err "prefetch-npm-deps via nix shell failed"
      return 1
    }
  fi

  echo "$hash"
}

# ── Rust cargoHash computation ──────────────────────────────────────
compute_cargo_hash() {
  local project="$1"
  local config_file="$CONFIGS_DIR/$project.json"
  local flake_input
  local cargo_lock_file
  flake_input=$(jq -r '.flakeInput' "$config_file")
  cargo_lock_file=$(jq -r '.cargoLockFile // empty' "$config_file")

  info "Computing cargoHash for ${BOLD}$project${NC}..." >&2
  info "This downloads cargo dependencies once (they'll be cached for the real build)..." >&2

  local store_path
  store_path=$(get_input_store_path "$flake_input") || return 1

  local cargo_lock_path=""
  local vendor_src="$store_path"

  if [ -n "$cargo_lock_file" ]; then
    cargo_lock_path="$REPO_ROOT/$cargo_lock_file"
    if [ ! -f "$cargo_lock_path" ]; then
      err "Configured cargoLockFile not found: $cargo_lock_path"
      return 1
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    local temp_src="$tmpdir/src"
    cp -R "$store_path" "$temp_src"
    chmod u+w "$temp_src"
    cp "$cargo_lock_path" "$temp_src/Cargo.lock"
    vendor_src="$temp_src"
  elif [ -f "$store_path/Cargo.lock" ]; then
    cargo_lock_path="$store_path/Cargo.lock"
  else
    err "No Cargo.lock found in $store_path"
    err "For repos without Cargo.lock, set cargoLockFile in lib/source-builds/configs/$project.json"
    return 1
  fi

  # Use nix build with an empty hash to trigger the FOD fetch,
  # then parse the correct hash from the error message.
  # The downloaded deps stay in the nix store cache.
  local pname
  pname=$(jq -r '.pname' "$config_file")

  local nix_expr
  nix_expr="(import <nixpkgs> {}).rustPlatform.fetchCargoVendor { src = $vendor_src; name = \"${pname}-vendor\"; hash = \"\"; }"

  info "Fetching cargo dependencies (single download)..." >&2
  local build_output
  build_output=$(nix build --impure --no-link --expr "$nix_expr" 2>&1) || true

  # Parse the hash from the error output
  # Nix outputs something like: "got:    sha256-xxxxx"
  # Use sed with a BRE-compatible pattern; macOS/BSD grep lacks -P (Perl regex).
  local hash
  hash=$(echo "$build_output" \
    | sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' \
    | head -1)

  if [ -z "$hash" ]; then
    # Try alternative format: "got: sha256:hexhash" (older nix versions).
    hash=$(echo "$build_output" \
      | sed -n 's/.*got:[[:space:]]*\(sha256:[a-f0-9]*\).*/\1/p' \
      | head -1)
    if [ -n "$hash" ]; then
      # Convert sha256:hex to sha256-base64 format
      local hex="${hash#sha256:}"
      hash="sha256-$(echo -n "$hex" | xxd -r -p | base64)"
    fi
  fi

  if [ -z "$hash" ]; then
    err "Could not extract cargoHash from nix build output."
    err "Build output:"
    echo "$build_output" | tail -20 >&2
    return 1
  fi

  echo "$hash"
}

# ── Update Logic ────────────────────────────────────────────────────
update_project() {
  local project="$1"
  local dry_run="${2:-false}"
  local refresh="${3:-false}"
  local config_file="$CONFIGS_DIR/$project.json"
  local hash_file="$HASHES_DIR/$project.json"

  if [ ! -f "$config_file" ]; then
    err "Config file not found: $config_file"
    return 1
  fi

  local flake_input build_system hash_field
  flake_input=$(jq -r '.flakeInput' "$config_file")
  build_system=$(jq -r '.buildSystem' "$config_file")
  hash_field=$(jq -r '.hashField' "$config_file")

  # Refresh flake input if requested
  if [ "$refresh" = "true" ]; then
    info "$project: refreshing flake input '$flake_input'..."
    nix flake update "$flake_input" --flake "$REPO_ROOT"
  fi

  # Get current locked rev
  local locked_rev
  locked_rev=$(get_locked_rev "$flake_input")

  if [ -z "$locked_rev" ]; then
    err "Could not find locked rev for flake input '$flake_input'"
    return 1
  fi

  # Check if hash file exists and is current
  local current_rev="(none)"
  if [ -f "$hash_file" ]; then
    current_rev=$(jq -r '.rev // "(none)"' "$hash_file")
  fi

  if [ "$current_rev" = "$locked_rev" ]; then
    ok "$project: hash is current (rev ${DIM}${locked_rev:0:7}${NC})"
    return 0
  fi

  if [ "$dry_run" = "true" ]; then
    echo -e "  ${YELLOW}$project${NC}: hash is stale (${DIM}${current_rev:0:7}${NC} -> ${BOLD}${locked_rev:0:7}${NC})"
    return 0
  fi

  info "$project: updating hash (rev ${DIM}${current_rev:0:7}${NC} -> ${BOLD}${locked_rev:0:7}${NC})"

  # Compute the new hash
  local new_hash
  case "$build_system" in
    npm)
      new_hash=$(compute_npm_hash "$project") || return 1
      ;;
    rust)
      new_hash=$(compute_cargo_hash "$project") || return 1
      ;;
    *)
      err "Unknown build system: $build_system"
      return 1
      ;;
  esac

  # Write the hash file
  jq -n \
    --arg rev "$locked_rev" \
    --arg hash "$new_hash" \
    --arg field "$hash_field" \
    '{ rev: $rev, ($field): $hash }' \
    > "$hash_file"

  ok "$project: hash updated (rev ${BOLD}${locked_rev:0:7}${NC})"
  echo -e "  ${DIM}$hash_field = $new_hash${NC}"
}

# ── List Logic ──────────────────────────────────────────────────────
list_projects() {
  echo -e "${BOLD}Configured source-built packages:${NC}"
  echo

  local has_projects=false
  for config_file in "$CONFIGS_DIR"/*.json; do
    [ -f "$config_file" ] || continue
    has_projects=true

    local project flake_input build_system pname hash_field
    project=$(basename "$config_file" .json)
    flake_input=$(jq -r '.flakeInput' "$config_file")
    build_system=$(jq -r '.buildSystem' "$config_file")
    pname=$(jq -r '.pname' "$config_file")
    hash_field=$(jq -r '.hashField' "$config_file")

    local hash_file="$HASHES_DIR/$project.json"
    local status_str locked_rev current_rev

    locked_rev=$(get_locked_rev "$flake_input")

    if [ -f "$hash_file" ]; then
      current_rev=$(jq -r '.rev // "(none)"' "$hash_file")
      if [ "$current_rev" = "$locked_rev" ]; then
        status_str="${GREEN}current${NC} (${DIM}${current_rev:0:7}${NC})"
      else
        status_str="${YELLOW}STALE${NC} (hash: ${DIM}${current_rev:0:7}${NC}, locked: ${BOLD}${locked_rev:0:7}${NC})"
      fi
    else
      status_str="${RED}no hash file${NC}"
    fi

    echo -e "  ${BOLD}$project${NC} ${DIM}($build_system, input: $flake_input)${NC}"
    echo -e "    Nix attr: pkgs.$pname"
    echo -e "    Status:   $status_str"
    echo
  done

  if [ "$has_projects" = "false" ]; then
    echo "  No packages configured yet."
    echo "  Run: $(basename "$0") add"
  fi
}

# ── Interactive Update ──────────────────────────────────────────────
cmd_update_interactive() {
  local refresh="${1:-false}"
  header "Update Source Build Hashes"

  local projects
  read -ra projects <<< "$(get_projects)"

  if [ ${#projects[@]} -eq 0 ]; then
    echo "No packages configured."
    return 0
  fi

  echo "Configured packages:"
  local i=1
  for project in "${projects[@]}"; do
    local build_system locked_rev current_rev status_indicator
    build_system=$(jq -r '.buildSystem' "$CONFIGS_DIR/$project.json")
    local flake_input
    flake_input=$(jq -r '.flakeInput' "$CONFIGS_DIR/$project.json")
    locked_rev=$(get_locked_rev "$flake_input")
    current_rev="(none)"
    status_indicator=""

    if [ -f "$HASHES_DIR/$project.json" ]; then
      current_rev=$(jq -r '.rev // "(none)"' "$HASHES_DIR/$project.json")
      if [ "$current_rev" != "$locked_rev" ]; then
        status_indicator=" ${YELLOW}[stale]${NC}"
      fi
    else
      status_indicator=" ${RED}[no hash]${NC}"
    fi

    echo -e "  ${BOLD}$i)${NC} $project ${DIM}($build_system)${NC}$status_indicator"
    ((i++))
  done
  echo
  echo -e "  ${BOLD}a)${NC} Update all"
  echo -e "  ${BOLD}q)${NC} Cancel"
  echo

  local selection
  read -rp "Select packages to update (space-separated numbers, or 'a' for all): " selection

  if [[ "$selection" == "q" ]] || [[ "$selection" == "Q" ]]; then
    echo "Cancelled."
    return 0
  fi

  echo

  if [[ "$selection" == "a" ]] || [[ "$selection" == "A" ]]; then
    local failed=0
    for project in "${projects[@]}"; do
      update_project "$project" "false" "$refresh" || ((failed++)) || true
    done
    if [ "$failed" -gt 0 ]; then
      err "$failed package(s) failed to update"
      return 1
    fi
  else
    local failed=0
    for num in $selection; do
      if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt ${#projects[@]} ]; then
        err "Invalid selection: $num"
        ((failed++)) || true
        continue
      fi
      update_project "${projects[$((num - 1))]}" "false" "$refresh" || ((failed++)) || true
    done
    if [ "$failed" -gt 0 ]; then
      err "$failed package(s) failed to update"
      return 1
    fi
  fi
}

# ── Add Logic ───────────────────────────────────────────────────────
cmd_add_interactive() {
  header "Add New Source-Built Package"

  echo "This registers an existing source-built overlay for automatic hash management."
  echo "The overlay .nix file must already exist and be wired into the overlay system."
  echo

  local project_name
  project_name=$(prompt_input "Package name (config identifier)" "")

  if [ -f "$CONFIGS_DIR/$project_name.json" ]; then
    err "Package '$project_name' already exists!"
    if ! prompt_yes_no "Overwrite?" "n"; then
      return 0
    fi
  fi

  local flake_input
  flake_input=$(prompt_input "Flake input name (as in flake.nix inputs)" "")

  # Verify the flake input exists in flake.lock
  local locked_rev
  locked_rev=$(get_locked_rev "$flake_input")
  if [ -z "$locked_rev" ]; then
    err "Flake input '$flake_input' not found in flake.lock"
    return 1
  fi
  success "Found input '$flake_input' at rev ${locked_rev:0:7}"

  echo
  echo "Build system:"
  echo -e "  ${BOLD}1)${NC} npm (uses prefetch-npm-deps)"
  echo -e "  ${BOLD}2)${NC} rust (uses fetchCargoVendor)"
  local bs_choice
  read -rp "Selection [1-2]: " bs_choice

  local build_system hash_field
  case "$bs_choice" in
    1) build_system="npm"; hash_field="npmDepsHash" ;;
    2) build_system="rust"; hash_field="cargoHash" ;;
    *) err "Invalid selection"; return 1 ;;
  esac

  local pname
  pname=$(prompt_input "Nix package name (pkgs.<name>)" "${project_name}-custom")

  # Write config
  jq -n \
    --arg flakeInput "$flake_input" \
    --arg buildSystem "$build_system" \
    --arg pname "$pname" \
    --arg hashField "$hash_field" \
    '{
      flakeInput: $flakeInput,
      buildSystem: $buildSystem,
      pname: $pname,
      hashField: $hashField
    }' > "$CONFIGS_DIR/$project_name.json"

  success "Config written: lib/source-builds/configs/$project_name.json"

  echo
  if prompt_yes_no "Compute hash now?" "y"; then
    update_project "$project_name"
  else
    echo
    echo "Run later:"
    echo "  ./scripts/source-build.sh update $project_name"
  fi

  echo
  echo -e "Remember to update your overlay to read the hash from:"
  echo -e "  ${BOLD}lib/source-builds/hashes/$project_name.json${NC}"
}

# ── Remove Logic ────────────────────────────────────────────────────
cmd_remove_interactive() {
  header "Remove Source-Built Package"

  local projects
  read -ra projects <<< "$(get_projects)"

  if [ ${#projects[@]} -eq 0 ]; then
    echo "No packages configured."
    return 0
  fi

  echo "Configured packages:"
  local i=1
  for project in "${projects[@]}"; do
    local pname
    pname=$(jq -r '.pname' "$CONFIGS_DIR/$project.json")
    echo -e "  ${BOLD}$i)${NC} $project ${DIM}(pkgs.$pname)${NC}"
    ((i++))
  done
  echo -e "  ${BOLD}q)${NC} Cancel"
  echo

  local selection
  read -rp "Select package to remove: " selection

  if [[ "$selection" == "q" ]] || [[ "$selection" == "Q" ]]; then
    echo "Cancelled."
    return 0
  fi

  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#projects[@]} ]; then
    err "Invalid selection"
    return 1
  fi

  local project="${projects[$((selection - 1))]}"
  do_remove "$project"
}

cmd_remove_by_name() {
  local project="$1"
  if [ ! -f "$CONFIGS_DIR/$project.json" ]; then
    err "Package '$project' not found"
    return 1
  fi
  do_remove "$project"
}

do_remove() {
  local project="$1"
  local pname
  pname=$(jq -r '.pname' "$CONFIGS_DIR/$project.json")

  warn "This will remove hash management for '${BOLD}$project${NC}' (pkgs.$pname)"
  echo "The overlay .nix file will NOT be deleted."

  if ! prompt_yes_no "Are you sure?" "n"; then
    echo "Cancelled."
    return 0
  fi

  rm -f "$CONFIGS_DIR/$project.json"
  rm -f "$HASHES_DIR/$project.json"

  success "Removed $project"
  echo
  echo "Remember to re-hardcode the hash in the overlay if you still use it."
}

# ── Main Menu ───────────────────────────────────────────────────────
main_menu() {
  header "Source Build Hash Manager"

  echo "What would you like to do?"
  echo
  echo -e "  ${BOLD}1)${NC} Update hashes for source-built packages"
  echo -e "  ${BOLD}2)${NC} Add a package to hash management"
  echo -e "  ${BOLD}3)${NC} Remove a package from hash management"
  echo -e "  ${BOLD}4)${NC} List configured packages"
  echo -e "  ${BOLD}5)${NC} Check for stale hashes"
  echo -e "  ${BOLD}q)${NC} Quit"
  echo

  local choice
  read -rp "Selection [1-5]: " choice

  case "$choice" in
    1) cmd_update_interactive ;;
    2) cmd_add_interactive ;;
    3) cmd_remove_interactive ;;
    4) list_projects ;;
    5)
      local projects
      read -ra projects <<< "$(get_projects)"
      local any_stale=false
      for project in "${projects[@]}"; do
        update_project "$project" "true" && true
        # Check if it printed a stale warning
      done
      ;;
    q|Q) exit 0 ;;
    *) err "Invalid selection"; exit 1 ;;
  esac
}

# ── Usage ───────────────────────────────────────────────────────────
usage() {
  echo "Usage: $(basename "$0") [COMMAND] [OPTIONS]"
  echo
  echo "Manage dependency hashes for source-built Nix packages."
  echo
  echo "Commands:"
  echo "  (none)             Interactive main menu"
  echo "  update [PACKAGE]   Update hash (interactive if no package given)"
  echo "  update --all       Update all hashes"
  echo "  update --refresh   Fetch latest source from flake input before updating"
  echo "  list               List packages with stale status"
  echo "  check [PACKAGE]    Check for stale hashes (dry run)"
  echo "  add                Interactive wizard to register a package"
  echo "  remove [PACKAGE]   Remove a package (interactive if no name given)"
  echo "  -h, --help         Show this help message"
  echo
  echo "Examples:"
  echo "  $(basename "$0")                                  # Interactive menu"
  echo "  $(basename "$0") update cronstrue                 # Update one package"
  echo "  $(basename "$0") update --all                     # Update all hashes"
  echo "  $(basename "$0") update tone-clone --refresh      # Fetch latest + update hash"
  echo "  $(basename "$0") update --all --refresh           # Fetch all latest + update"
  echo "  $(basename "$0") check                            # Check all for staleness"
  echo "  $(basename "$0") list                             # Show status"
  echo
  echo "Typical workflow after 'nix flake update':"
  echo "  $(basename "$0") check                            # See what's stale"
  echo "  $(basename "$0") update --all                     # Fix all stale hashes"
  echo
  echo "Or refresh a specific input and update in one step:"
  echo "  $(basename "$0") update tone-clone --refresh"
}

# ── Entry Point ─────────────────────────────────────────────────────
main() {
  if [ $# -eq 0 ]; then
    main_menu
    exit 0
  fi

  local command="$1"
  shift

  case "$command" in
    update)
      local refresh=false
      local args=()
      for arg in "$@"; do
        if [ "$arg" = "--refresh" ]; then
          refresh=true
        else
          args+=("$arg")
        fi
      done
      if [ ${#args[@]} -eq 0 ]; then
        cmd_update_interactive "$refresh"
      elif [ "${args[0]}" = "--all" ]; then
        local projects
        read -ra projects <<< "$(get_projects)"
        local failed=0
        for project in "${projects[@]}"; do
          update_project "$project" "false" "$refresh" || ((failed++)) || true
        done
        if [ "$failed" -gt 0 ]; then
          exit 1
        fi
      else
        local failed=0
        for project in "${args[@]}"; do
          update_project "$project" "false" "$refresh" || ((failed++)) || true
        done
        if [ "$failed" -gt 0 ]; then
          exit 1
        fi
      fi
      ;;
    list)
      list_projects
      ;;
    check)
      if [ $# -eq 0 ]; then
        local projects
        read -ra projects <<< "$(get_projects)"
        for project in "${projects[@]}"; do
          update_project "$project" "true"
        done
      else
        for project in "$@"; do
          update_project "$project" "true"
        done
      fi
      ;;
    add)
      cmd_add_interactive
      ;;
    remove)
      if [ $# -eq 0 ]; then
        cmd_remove_interactive
      else
        cmd_remove_by_name "$1"
      fi
      ;;
    -h|--help)
      usage
      ;;
    *)
      err "Unknown command: $command"
      echo
      usage
      exit 1
      ;;
  esac
}

main "$@"

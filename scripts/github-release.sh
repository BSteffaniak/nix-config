#!/usr/bin/env bash
# github-release.sh - Manage GitHub release binary packages for Nix
#
# Interactive mode (main menu):
#   ./scripts/github-release.sh
#
# Subcommands:
#   ./scripts/github-release.sh update                    # Interactive: pick projects to update
#   ./scripts/github-release.sh update --all              # Non-interactive: update all
#   ./scripts/github-release.sh update <name>             # Non-interactive: update one
#   ./scripts/github-release.sh add                       # Interactive: wizard to add new project
#   ./scripts/github-release.sh add --non-interactive \   # Non-interactive: create from args
#       --owner org --repo tool --pname tool-dev ...
#   ./scripts/github-release.sh remove                    # Interactive: pick project to remove
#   ./scripts/github-release.sh remove <name>             # Non-interactive: remove by name
#   ./scripts/github-release.sh list                      # List all configured projects
#   ./scripts/github-release.sh check                     # Check all for updates (dry run)
#   ./scripts/github-release.sh check <name>              # Check one for updates (dry run)
#
# Requires: curl, jq
# Optional: nix-prefetch-url (fallback for missing GitHub API digests)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$REPO_ROOT/lib/github-releases/configs"
VERSIONS_DIR="$REPO_ROOT/lib/github-releases/versions"

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
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "Required command '$cmd' not found. Please install it."
    exit 1
  fi
done

# Ensure directories exist
mkdir -p "$CONFIGS_DIR" "$VERSIONS_DIR"

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

# Get list of configured project names
get_projects() {
  local projects=()
  for config_file in "$CONFIGS_DIR"/*.json; do
    [ -f "$config_file" ] || continue
    projects+=("$(basename "$config_file" .json)")
  done
  echo "${projects[@]}"
}

# Get the sha256 hash for an asset
get_asset_hash() {
  local asset_json="$1"
  local digest

  # Try the GitHub API digest field first (format: "sha256:hexhash")
  digest=$(echo "$asset_json" | jq -r '.digest // empty')

  if [ -n "$digest" ] && [[ "$digest" == sha256:* ]]; then
    echo "${digest#sha256:}"
    return 0
  fi

  # Fall back to nix-prefetch-url
  local url
  url=$(echo "$asset_json" | jq -r '.browser_download_url')

  if command -v nix-prefetch-url &>/dev/null; then
    warn "No digest in API response, falling back to nix-prefetch-url for: $(basename "$url")"
    local store_hash
    store_hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
    echo "$store_hash"
    return 0
  fi

  err "No digest in API response and nix-prefetch-url not available"
  return 1
}

# Fetch release data from GitHub API
fetch_release() {
  local owner="$1"
  local repo="$2"
  local api_url="https://api.github.com/repos/$owner/$repo/releases/latest"

  local release_json
  release_json=$(curl -sL -H "Accept: application/vnd.github+json" "$api_url")

  # Check for API errors
  if echo "$release_json" | jq -e '.message' &>/dev/null; then
    local message
    message=$(echo "$release_json" | jq -r '.message')
    err "GitHub API error for $owner/$repo: $message"
    return 1
  fi

  echo "$release_json"
}

# ── Update Logic ────────────────────────────────────────────────────
update_project() {
  local project="$1"
  local dry_run="${2:-false}"
  local config_file="$CONFIGS_DIR/$project.json"
  local version_file="$VERSIONS_DIR/$project.json"

  if [ ! -f "$config_file" ]; then
    err "Config file not found: $config_file"
    return 1
  fi

  local owner repo strip_prefix
  owner=$(jq -r '.owner' "$config_file")
  repo=$(jq -r '.repo' "$config_file")
  strip_prefix=$(jq -r '.stripVersionPrefix // ""' "$config_file")

  info "Fetching latest release for ${BOLD}$owner/$repo${NC}..."

  local release_json
  release_json=$(fetch_release "$owner" "$repo") || return 1

  local tag_name version
  tag_name=$(echo "$release_json" | jq -r '.tag_name')

  if [ -n "$strip_prefix" ]; then
    version="${tag_name#"$strip_prefix"}"
  else
    version="$tag_name"
  fi

  local current_version="(none)"
  if [ -f "$version_file" ]; then
    current_version=$(jq -r '.version' "$version_file")
  fi

  if [ "$current_version" = "$version" ] && [ "$dry_run" = "false" ]; then
    ok "$project: already at ${BOLD}v$version${NC}"
    return 0
  fi

  if [ "$dry_run" = "true" ]; then
    if [ "$current_version" = "$version" ]; then
      ok "$project: up to date at ${BOLD}v$version${NC}"
    else
      echo -e "  ${YELLOW}$project${NC}: ${current_version} -> ${BOLD}${GREEN}$version${NC}"
    fi
    return 0
  fi

  info "$project: updating ${current_version} -> ${BOLD}$version${NC}"

  local platforms_json="{}"
  local platform asset_name

  while IFS= read -r platform; do
    asset_name=$(jq -r ".platforms[\"$platform\"]" "$config_file")

    local asset_json
    asset_json=$(echo "$release_json" | jq --arg name "$asset_name" '.assets[] | select(.name == $name)')

    if [ -z "$asset_json" ]; then
      warn "Asset '$asset_name' not found in release $tag_name for platform $platform, skipping"
      continue
    fi

    local download_url sha256
    download_url=$(echo "$asset_json" | jq -r '.browser_download_url')

    sha256=$(get_asset_hash "$asset_json")
    if [ $? -ne 0 ] || [ -z "$sha256" ]; then
      err "Failed to get hash for $asset_name"
      continue
    fi

    platforms_json=$(echo "$platforms_json" | jq \
      --arg platform "$platform" \
      --arg url "$download_url" \
      --arg sha256 "$sha256" \
      '.[$platform] = { url: $url, sha256: $sha256 }')

    ok "  $platform: $asset_name"
  done < <(jq -r '.platforms | keys[]' "$config_file")

  local platform_count
  platform_count=$(echo "$platforms_json" | jq 'length')
  if [ "$platform_count" -eq 0 ]; then
    err "No platforms found for $project in release $tag_name"
    return 1
  fi

  jq -n \
    --arg version "$version" \
    --arg tag "$tag_name" \
    --argjson platforms "$platforms_json" \
    '{ version: $version, tag: $tag, platforms: $platforms }' \
    > "$version_file"

  ok "$project: updated to ${BOLD}v$version${NC} ($platform_count platforms)"
}

# ── List Logic ──────────────────────────────────────────────────────
list_projects() {
  echo -e "${BOLD}Configured GitHub release projects:${NC}"
  echo

  local has_projects=false
  for config_file in "$CONFIGS_DIR"/*.json; do
    [ -f "$config_file" ] || continue
    has_projects=true

    local project owner repo pname current_version
    project=$(basename "$config_file" .json)
    owner=$(jq -r '.owner' "$config_file")
    repo=$(jq -r '.repo' "$config_file")
    pname=$(jq -r '.pname' "$config_file")

    local version_file="$VERSIONS_DIR/$project.json"
    if [ -f "$version_file" ]; then
      current_version=$(jq -r '.version' "$version_file")
    else
      current_version="${DIM}(not yet fetched)${NC}"
    fi

    local platforms
    platforms=$(jq -r '.platforms | keys | join(", ")' "$config_file")

    echo -e "  ${BOLD}$project${NC} ${DIM}($owner/$repo)${NC}"
    echo -e "    Nix attr:  pkgs.$pname"
    echo -e "    Version:   $current_version"
    echo -e "    Platforms: $platforms"
    echo
  done

  if [ "$has_projects" = "false" ]; then
    echo "  No projects configured yet."
    echo "  Run: $(basename "$0") add"
  fi
}

# ── Auto-detect platform mapping ────────────────────────────────────
# Given a list of asset names, try to match them to Nix platform strings
auto_detect_platforms() {
  local release_json="$1"

  # Get asset names, filtering out signatures, desktop apps, installers, and metadata
  local assets
  assets=$(echo "$release_json" | jq -r '.assets[].name' | \
    grep -v -E '\.(sig|deb|rpm|dmg|exe|msi|AppImage|blockmap)$' | \
    grep -v -E '(desktop-|latest\.json|SHASUMS|checksums)' | \
    sort)

  local -A detected=()

  while IFS= read -r asset; do
    [ -z "$asset" ] && continue
    local lower
    lower=$(echo "$asset" | tr '[:upper:]' '[:lower:]')

    local os="" arch=""

    # Detect OS
    if [[ "$lower" == *linux* ]]; then
      os="linux"
    elif [[ "$lower" == *darwin* ]] || [[ "$lower" == *macos* ]] || [[ "$lower" == *osx* ]]; then
      os="darwin"
    fi

    # Detect architecture
    if [[ "$lower" == *x86_64* ]] || [[ "$lower" == *x64* ]] || [[ "$lower" == *amd64* ]]; then
      arch="x86_64"
    elif [[ "$lower" == *aarch64* ]] || [[ "$lower" == *arm64* ]]; then
      arch="aarch64"
    fi

    if [ -n "$os" ] && [ -n "$arch" ]; then
      local platform="${arch}-${os}"
      # Only set if not already detected (first match wins — prefer non-musl)
      if [ -z "${detected[$platform]:-}" ]; then
        # Skip musl variants if there's likely a glibc one
        if [[ "$lower" == *musl* ]]; then
          continue
        fi
        # Skip "baseline" variants
        if [[ "$lower" == *baseline* ]]; then
          continue
        fi
        detected[$platform]="$asset"
      fi
    fi
  done <<< "$assets"

  # Output as JSON
  local platforms_json="{}"
  for platform in "${!detected[@]}"; do
    platforms_json=$(echo "$platforms_json" | jq \
      --arg p "$platform" \
      --arg a "${detected[$platform]}" \
      '.[$p] = $a')
  done
  echo "$platforms_json"
}

# ── Add Logic (Interactive) ─────────────────────────────────────────
cmd_add_interactive() {
  header "Add New GitHub Release Project"

  # Step 1: GitHub repo
  local repo_input owner repo
  repo_input=$(prompt_input "GitHub repo (owner/repo)" "")

  if [[ "$repo_input" != */* ]]; then
    err "Invalid format. Expected: owner/repo"
    exit 1
  fi

  owner="${repo_input%%/*}"
  repo="${repo_input##*/}"

  # Step 2: Fetch latest release
  info "Fetching latest release for ${BOLD}$owner/$repo${NC}..."
  local release_json
  release_json=$(fetch_release "$owner" "$repo") || exit 1

  local tag_name
  tag_name=$(echo "$release_json" | jq -r '.tag_name')
  local asset_count
  asset_count=$(echo "$release_json" | jq '.assets | length')

  success "Latest release: ${BOLD}$tag_name${NC} ($asset_count assets)"
  echo

  # Show filtered assets
  echo -e "${BOLD}Available assets (filtered):${NC}"
  local assets_filtered
  assets_filtered=$(echo "$release_json" | jq -r '.assets[].name' | \
    grep -v -E '\.(sig|deb|rpm|dmg|exe|msi|AppImage|blockmap)$' | \
    grep -v -E '(desktop-|latest\.json|SHASUMS|checksums)' | \
    sort)

  local i=1
  while IFS= read -r asset; do
    [ -z "$asset" ] && continue
    echo -e "  ${DIM}$i)${NC} $asset"
    ((i++))
  done <<< "$assets_filtered"
  echo

  # Step 3: Project name (used as config filename and identifier)
  local project_name
  project_name=$(prompt_input "Project name (config identifier)" "$repo")

  # Check if already exists
  if [ -f "$CONFIGS_DIR/$project_name.json" ]; then
    err "Project '$project_name' already exists!"
    if ! prompt_yes_no "Overwrite existing configuration?" "n"; then
      echo "Aborting."
      exit 0
    fi
  fi

  # Step 4: Package name
  local pname
  pname=$(prompt_input "Nix package name (pkgs.<name>)" "${repo}-dev")

  # Step 5: Binary name
  local binary_name
  binary_name=$(prompt_input "Binary name in archive" "$repo")

  # Step 6: Installed binary name
  local installed_binary_name
  installed_binary_name=$(prompt_input "Installed binary name" "$pname")

  # Step 7: Version prefix
  local strip_prefix=""
  if [[ "$tag_name" == v* ]]; then
    strip_prefix="v"
    echo -e "  ${DIM}Tag '$tag_name' starts with 'v', suggesting prefix strip.${NC}"
  fi
  strip_prefix=$(prompt_input "Version prefix to strip" "$strip_prefix")

  # Step 8: Platform mapping
  echo
  echo -e "${BOLD}Detecting platform mapping...${NC}"
  local auto_platforms
  auto_platforms=$(auto_detect_platforms "$release_json")

  local platform_count
  platform_count=$(echo "$auto_platforms" | jq 'length')

  if [ "$platform_count" -gt 0 ]; then
    echo
    echo -e "${BOLD}Auto-detected platform mapping:${NC}"
    echo "$auto_platforms" | jq -r 'to_entries[] | "  \(.key) -> \(.value)"'
    echo

    if prompt_yes_no "Accept this mapping?" "y"; then
      : # keep auto_platforms
    else
      auto_platforms=$(manual_platform_mapping "$release_json")
    fi
  else
    warn "Could not auto-detect platforms from asset names."
    auto_platforms=$(manual_platform_mapping "$release_json")
  fi

  # Step 9: License
  echo
  echo -e "${BOLD}Common licenses:${NC} mit, asl20, bsd2, bsd3, gpl2, gpl3, mpl20, isc, unlicense, unfree"
  local license
  license=$(prompt_input "License" "mit")

  # Step 10: Description
  local description
  description=$(prompt_input "Description" "$repo (from GitHub releases)")

  # Step 11: Write config
  echo
  info "Writing config: ${BOLD}lib/github-releases/configs/$project_name.json${NC}"

  jq -n \
    --arg owner "$owner" \
    --arg repo "$repo" \
    --arg pname "$pname" \
    --arg binaryName "$binary_name" \
    --arg installedBinaryName "$installed_binary_name" \
    --arg stripVersionPrefix "$strip_prefix" \
    --argjson platforms "$auto_platforms" \
    --arg description "$description" \
    --arg homepage "https://github.com/$owner/$repo" \
    --arg license "$license" \
    '{
      owner: $owner,
      repo: $repo,
      pname: $pname,
      binaryName: $binaryName,
      installedBinaryName: $installedBinaryName,
      stripVersionPrefix: $stripVersionPrefix,
      platforms: $platforms,
      meta: {
        description: $description,
        homepage: $homepage,
        license: $license
      }
    }' > "$CONFIGS_DIR/$project_name.json"

  success "Config written"

  # Step 12: Fetch version data
  echo
  info "Fetching version data..."
  update_project "$project_name"

  # Step 13: Summary
  header "Done!"

  echo "Created files:"
  echo "  lib/github-releases/configs/$project_name.json"
  echo "  lib/github-releases/versions/$project_name.json"
  echo
  echo "The overlay auto-discovers this config. No Nix files to edit."
  echo
  echo -e "Add to your ${BOLD}home.nix${NC}:"
  echo -e "  ${GREEN}pkgs.$pname${NC}"
  echo
  echo "Then rebuild:"
  echo "  darwin-rebuild switch --flake ."
}

# Manual platform mapping (fallback when auto-detect fails)
manual_platform_mapping() {
  local release_json="$1"

  echo
  echo -e "${BOLD}Manual platform mapping${NC}"
  echo "For each Nix platform, enter the asset filename (or leave blank to skip)."
  echo

  local all_assets
  all_assets=$(echo "$release_json" | jq -r '.assets[].name' | sort)

  echo -e "${DIM}Available assets:${NC}"
  echo "$all_assets" | while IFS= read -r a; do echo "  $a"; done
  echo

  local platforms_json="{}"

  for platform in x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin; do
    local asset
    asset=$(prompt_input "  $platform" "")
    if [ -n "$asset" ]; then
      platforms_json=$(echo "$platforms_json" | jq \
        --arg p "$platform" \
        --arg a "$asset" \
        '.[$p] = $a')
    fi
  done

  echo "$platforms_json"
}

# ── Add Logic (Non-Interactive) ─────────────────────────────────────
cmd_add_non_interactive() {
  local owner="" repo="" pname="" binary_name="" installed_binary_name=""
  local strip_prefix="" license="mit" description=""
  # Platform asset names
  local x86_64_linux="" aarch64_linux="" x86_64_darwin="" aarch64_darwin=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --owner)                  owner="$2"; shift 2 ;;
      --repo)                   repo="$2"; shift 2 ;;
      --pname)                  pname="$2"; shift 2 ;;
      --binary-name)            binary_name="$2"; shift 2 ;;
      --installed-binary-name)  installed_binary_name="$2"; shift 2 ;;
      --strip-prefix)           strip_prefix="$2"; shift 2 ;;
      --license)                license="$2"; shift 2 ;;
      --description)            description="$2"; shift 2 ;;
      --x86_64-linux)           x86_64_linux="$2"; shift 2 ;;
      --aarch64-linux)          aarch64_linux="$2"; shift 2 ;;
      --x86_64-darwin)          x86_64_darwin="$2"; shift 2 ;;
      --aarch64-darwin)         aarch64_darwin="$2"; shift 2 ;;
      --non-interactive)        shift ;; # already in non-interactive mode
      *)                        err "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Validate required fields
  if [ -z "$owner" ] || [ -z "$repo" ]; then
    err "--owner and --repo are required"
    exit 1
  fi

  # Defaults
  local project_name="$repo"
  pname="${pname:-${repo}-dev}"
  binary_name="${binary_name:-$repo}"
  installed_binary_name="${installed_binary_name:-$pname}"
  description="${description:-$repo (from GitHub releases)}"

  # If no platforms specified, try auto-detection
  if [ -z "$x86_64_linux" ] && [ -z "$aarch64_linux" ] && [ -z "$x86_64_darwin" ] && [ -z "$aarch64_darwin" ]; then
    info "No platforms specified, attempting auto-detection..."
    local release_json
    release_json=$(fetch_release "$owner" "$repo") || exit 1

    local auto_platforms
    auto_platforms=$(auto_detect_platforms "$release_json")
    local count
    count=$(echo "$auto_platforms" | jq 'length')

    if [ "$count" -eq 0 ]; then
      err "Could not auto-detect platforms. Please specify them manually."
      exit 1
    fi

    info "Auto-detected $count platforms"

    # Write config with auto-detected platforms
    jq -n \
      --arg owner "$owner" \
      --arg repo "$repo" \
      --arg pname "$pname" \
      --arg binaryName "$binary_name" \
      --arg installedBinaryName "$installed_binary_name" \
      --arg stripVersionPrefix "$strip_prefix" \
      --argjson platforms "$auto_platforms" \
      --arg description "$description" \
      --arg homepage "https://github.com/$owner/$repo" \
      --arg license "$license" \
      '{
        owner: $owner,
        repo: $repo,
        pname: $pname,
        binaryName: $binaryName,
        installedBinaryName: $installedBinaryName,
        stripVersionPrefix: $stripVersionPrefix,
        platforms: $platforms,
        meta: {
          description: $description,
          homepage: $homepage,
          license: $license
        }
      }' > "$CONFIGS_DIR/$project_name.json"
  else
    # Build platforms from args
    local platforms_json="{}"
    [ -n "$x86_64_linux" ] && platforms_json=$(echo "$platforms_json" | jq --arg a "$x86_64_linux" '.["x86_64-linux"] = $a')
    [ -n "$aarch64_linux" ] && platforms_json=$(echo "$platforms_json" | jq --arg a "$aarch64_linux" '.["aarch64-linux"] = $a')
    [ -n "$x86_64_darwin" ] && platforms_json=$(echo "$platforms_json" | jq --arg a "$x86_64_darwin" '.["x86_64-darwin"] = $a')
    [ -n "$aarch64_darwin" ] && platforms_json=$(echo "$platforms_json" | jq --arg a "$aarch64_darwin" '.["aarch64-darwin"] = $a')

    jq -n \
      --arg owner "$owner" \
      --arg repo "$repo" \
      --arg pname "$pname" \
      --arg binaryName "$binary_name" \
      --arg installedBinaryName "$installed_binary_name" \
      --arg stripVersionPrefix "$strip_prefix" \
      --argjson platforms "$platforms_json" \
      --arg description "$description" \
      --arg homepage "https://github.com/$owner/$repo" \
      --arg license "$license" \
      '{
        owner: $owner,
        repo: $repo,
        pname: $pname,
        binaryName: $binaryName,
        installedBinaryName: $installedBinaryName,
        stripVersionPrefix: $stripVersionPrefix,
        platforms: $platforms,
        meta: {
          description: $description,
          homepage: $homepage,
          license: $license
        }
      }' > "$CONFIGS_DIR/$project_name.json"
  fi

  success "Config written: $CONFIGS_DIR/$project_name.json"

  # Fetch version data
  update_project "$project_name"
}

# ── Remove Logic ────────────────────────────────────────────────────
cmd_remove_interactive() {
  header "Remove GitHub Release Project"

  local projects
  read -ra projects <<< "$(get_projects)"

  if [ ${#projects[@]} -eq 0 ]; then
    echo "No projects configured."
    return 0
  fi

  echo "Configured projects:"
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
  read -rp "Select project to remove: " selection

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
    err "Project '$project' not found"
    return 1
  fi

  do_remove "$project"
}

do_remove() {
  local project="$1"
  local pname
  pname=$(jq -r '.pname' "$CONFIGS_DIR/$project.json")

  echo
  warn "This will remove project '${BOLD}$project${NC}' (pkgs.$pname)"

  if ! prompt_yes_no "Are you sure?" "n"; then
    echo "Cancelled."
    return 0
  fi

  rm -f "$CONFIGS_DIR/$project.json"
  rm -f "$VERSIONS_DIR/$project.json"

  success "Removed $project"
  echo
  echo -e "Remember to remove ${BOLD}pkgs.$pname${NC} from your home.nix files."
}

# ── Interactive Update ──────────────────────────────────────────────
cmd_update_interactive() {
  header "Update GitHub Release Projects"

  local projects
  read -ra projects <<< "$(get_projects)"

  if [ ${#projects[@]} -eq 0 ]; then
    echo "No projects configured."
    return 0
  fi

  echo "Configured projects:"
  local i=1
  for project in "${projects[@]}"; do
    local owner repo current_version
    owner=$(jq -r '.owner' "$CONFIGS_DIR/$project.json")
    repo=$(jq -r '.repo' "$CONFIGS_DIR/$project.json")
    if [ -f "$VERSIONS_DIR/$project.json" ]; then
      current_version=$(jq -r '.version' "$VERSIONS_DIR/$project.json")
    else
      current_version="(not yet fetched)"
    fi
    echo -e "  ${BOLD}$i)${NC} $project ${DIM}($owner/$repo v$current_version)${NC}"
    ((i++))
  done
  echo
  echo -e "  ${BOLD}a)${NC} Update all"
  echo -e "  ${BOLD}q)${NC} Cancel"
  echo

  local selection
  read -rp "Select projects to update (space-separated numbers, or 'a' for all): " selection

  if [[ "$selection" == "q" ]] || [[ "$selection" == "Q" ]]; then
    echo "Cancelled."
    return 0
  fi

  echo

  if [[ "$selection" == "a" ]] || [[ "$selection" == "A" ]]; then
    local failed=0
    for project in "${projects[@]}"; do
      update_project "$project" || ((failed++))
    done
    if [ "$failed" -gt 0 ]; then
      err "$failed project(s) failed to update"
      return 1
    fi
  else
    local failed=0
    for num in $selection; do
      if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt ${#projects[@]} ]; then
        err "Invalid selection: $num"
        ((failed++))
        continue
      fi
      update_project "${projects[$((num - 1))]}" || ((failed++))
    done
    if [ "$failed" -gt 0 ]; then
      err "$failed project(s) failed to update"
      return 1
    fi
  fi
}

# ── Main Menu ───────────────────────────────────────────────────────
main_menu() {
  header "GitHub Release Manager"

  echo "What would you like to do?"
  echo
  echo -e "  ${BOLD}1)${NC} Update existing projects"
  echo -e "  ${BOLD}2)${NC} Add a new project"
  echo -e "  ${BOLD}3)${NC} Remove a project"
  echo -e "  ${BOLD}4)${NC} List configured projects"
  echo -e "  ${BOLD}5)${NC} Check for updates (dry run)"
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
      for project in "${projects[@]}"; do
        update_project "$project" "true"
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
  echo "Manage GitHub release binary packages for Nix."
  echo
  echo "Commands:"
  echo "  (none)             Interactive main menu"
  echo "  update [PROJECT]   Update version data (interactive if no project given)"
  echo "  update --all       Update all projects"
  echo "  add                Interactive wizard to add a new project"
  echo "  add --non-interactive --owner ORG --repo REPO [...]"
  echo "                     Add a new project from command-line arguments"
  echo "  remove [PROJECT]   Remove a project (interactive if no project given)"
  echo "  list               List all configured projects"
  echo "  check [PROJECT]    Check for updates without writing (dry run)"
  echo "  -h, --help         Show this help message"
  echo
  echo "Examples:"
  echo "  $(basename "$0")                                 # Interactive menu"
  echo "  $(basename "$0") update opencode                 # Update one project"
  echo "  $(basename "$0") update pi                       # (or any other configured project)"
  echo "  $(basename "$0") update --all                    # Update all projects"
  echo "  $(basename "$0") add                             # Interactive add wizard"
  echo "  $(basename "$0") add --non-interactive --owner sst --repo opencode --pname opencode-dev"
  echo "  $(basename "$0") remove opencode                 # Remove a project"
  echo "  $(basename "$0") check                           # Dry-run check all"
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
      if [ $# -eq 0 ]; then
        cmd_update_interactive
      elif [ "$1" = "--all" ]; then
        local projects
        read -ra projects <<< "$(get_projects)"
        local failed=0
        for project in "${projects[@]}"; do
          update_project "$project" || ((failed++))
        done
        if [ "$failed" -gt 0 ]; then
          exit 1
        fi
      else
        local failed=0
        for project in "$@"; do
          update_project "$project" || ((failed++))
        done
        if [ "$failed" -gt 0 ]; then
          exit 1
        fi
      fi
      ;;
    add)
      if [ $# -eq 0 ]; then
        cmd_add_interactive
      else
        # Check if --non-interactive is present
        local non_interactive=false
        for arg in "$@"; do
          if [ "$arg" = "--non-interactive" ]; then
            non_interactive=true
            break
          fi
        done
        if [ "$non_interactive" = "true" ]; then
          cmd_add_non_interactive "$@"
        else
          cmd_add_interactive
        fi
      fi
      ;;
    remove)
      if [ $# -eq 0 ]; then
        cmd_remove_interactive
      else
        cmd_remove_by_name "$1"
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

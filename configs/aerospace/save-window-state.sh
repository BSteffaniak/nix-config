#!/bin/bash
# Save window-to-workspace assignments for persistence across reboots.
#
# For each window, saves:
#   - app-bundle-id (stable across reboots)
#   - title-pattern (extracted stable suffix for multi-window apps like Edge profiles)
#   - workspace
#
# The title-pattern extraction handles:
#   - Chromium-based browsers (Edge, Chrome, Brave, Arc): "- <BrowserName> - <Profile>"
#   - Firefox profiles: "- Mozilla Firefox" (+ optional profile indicator)
#   - Other apps: empty string (matched by bundle-id alone)
#
# For single-window apps, bundle-id alone is sufficient.
# For multi-window apps, the title-pattern disambiguates which window goes where.

STATE_DIR="$HOME/.local/state/aerospace"
STATE_FILE="$STATE_DIR/window-workspaces.json"
LOG_FILE="$STATE_DIR/debug.log"
LOCK_FILE="$STATE_DIR/restore-windows.lock"

mkdir -p "$STATE_DIR"

# Skip saving if a restore is in progress
if [[ -f "$LOCK_FILE" ]]; then
  echo "[$(date)] save-window-state: Skipping - restore in progress" >> "$LOG_FILE"
  exit 0
fi

# Extract a stable "title pattern" from a window title.
# This pattern must survive across reboots (page titles change, but profile suffixes don't).
extract_title_pattern() {
  local bundle_id="$1"
  local title="$2"

  case "$bundle_id" in
    # Chromium-based browsers: extract "- <Browser> - <Profile>" or "- <Browser> (InPrivate/Incognito)"
    com.microsoft.edgemac|com.microsoft.edgemac.*)
      # Edge: "Page Title - Microsoft Edge - ProfileName" or "Page Title - Microsoft Edge (InPrivate)"
      if [[ "$title" =~ -\ Microsoft\ Edge\ -\ (.+)$ ]]; then
        echo "- Microsoft Edge - ${BASH_REMATCH[1]}"
      elif [[ "$title" =~ -\ Microsoft\ Edge\ \(InPrivate\)$ ]]; then
        echo "- Microsoft Edge (InPrivate)"
      fi
      ;;
    com.google.Chrome|com.google.Chrome.*)
      if [[ "$title" =~ -\ Google\ Chrome\ -\ (.+)$ ]]; then
        echo "- Google Chrome - ${BASH_REMATCH[1]}"
      elif [[ "$title" =~ -\ Google\ Chrome\ \(Incognito\)$ ]]; then
        echo "- Google Chrome (Incognito)"
      fi
      ;;
    com.brave.Browser|com.brave.Browser.*)
      if [[ "$title" =~ -\ Brave\ -\ (.+)$ ]]; then
        echo "- Brave - ${BASH_REMATCH[1]}"
      elif [[ "$title" =~ -\ Brave\ \(Private\)$ ]]; then
        echo "- Brave (Private)"
      fi
      ;;
    # For all other apps: no pattern needed (bundle-id alone is sufficient)
    # If an app has multiple windows they'll all map to the same workspace,
    # which is correct for most apps (e.g., multiple Finder windows).
    *)
      echo ""
      ;;
  esac
}

# Collect window data using --format (gives us bundle-id which --json doesn't)
# Delimiter: ASCII unit separator (0x1f) to avoid conflicts with window titles
SEP=$'\x1f'
window_data=$(aerospace list-windows --all --format "%{app-bundle-id}${SEP}%{window-title}${SEP}%{workspace}")

if [[ -z "$window_data" ]]; then
  echo "[$(date)] save-window-state: No windows found, skipping save" >> "$LOG_FILE"
  exit 0
fi

# Build JSON array of window entries, deduplicating by (bundle-id, title-pattern, workspace)
declare -A seen
json_entries=()

while IFS="$SEP" read -r bundle_id title workspace; do
  [[ -z "$bundle_id" ]] && continue
  [[ -z "$workspace" ]] && continue

  pattern=$(extract_title_pattern "$bundle_id" "$title")
  dedup_key="${bundle_id}|${pattern}|${workspace}"

  # Skip duplicates (e.g., multiple windows of same app+profile on same workspace)
  if [[ -n "${seen[$dedup_key]}" ]]; then
    continue
  fi
  seen[$dedup_key]=1

  # Escape strings for JSON (handle quotes and backslashes)
  esc_bundle_id=$(printf '%s' "$bundle_id" | sed 's/\\/\\\\/g; s/"/\\"/g')
  esc_pattern=$(printf '%s' "$pattern" | sed 's/\\/\\\\/g; s/"/\\"/g')
  esc_workspace=$(printf '%s' "$workspace" | sed 's/\\/\\\\/g; s/"/\\"/g')

  json_entries+=("  {\"app-bundle-id\": \"${esc_bundle_id}\", \"title-pattern\": \"${esc_pattern}\", \"workspace\": \"${esc_workspace}\"}")
done <<< "$window_data"

# Write JSON array
{
  echo "["
  local_len=${#json_entries[@]}
  for ((i=0; i<local_len; i++)); do
    if ((i < local_len - 1)); then
      echo "${json_entries[$i]},"
    else
      echo "${json_entries[$i]}"
    fi
  done
  echo "]"
} > "$STATE_FILE"

echo "[$(date)] save-window-state: Saved ${#json_entries[@]} entries to $STATE_FILE" >> "$LOG_FILE"

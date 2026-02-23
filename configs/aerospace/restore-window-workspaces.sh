#!/bin/bash
# Restore window-to-workspace assignments from saved state after reboot.
#
# Uses a polling loop to handle apps that take time to launch:
# - Checks every 2 seconds for up to 60 seconds
# - On each poll, matches currently-open windows against saved state
# - Moves matched windows to their saved workspace
# - Tracks which save entries have been satisfied
# - Exits early once all entries are satisfied or no new windows appear
#
# Matching logic:
# 1. For entries WITH a title-pattern: match by app-bundle-id AND title containing the pattern
# 2. For entries WITHOUT a title-pattern: match by app-bundle-id alone
#    - If multiple windows share a bundle-id with no pattern, they all go to the same workspace
#    - This is correct for most apps (e.g., multiple Finder windows)
#
# NOTE: The lock file prevents save-window-state.sh from overwriting saved state
#       while we're still restoring (some windows may not have launched yet).

STATE_DIR="$HOME/.local/state/aerospace"
STATE_FILE="$STATE_DIR/window-workspaces.json"
LOCK_FILE="$STATE_DIR/restore-windows.lock"
LOG_FILE="$STATE_DIR/debug.log"

POLL_INTERVAL=2
MAX_WAIT=60

mkdir -p "$STATE_DIR"

log() {
  echo "[$(date)] restore-windows: $1" >> "$LOG_FILE"
}

# Create lock file to prevent save handler from overwriting state during restore
cleanup() {
  rm -f "$LOCK_FILE"
  log "Lock released"
}
touch "$LOCK_FILE"
trap cleanup EXIT

log "Starting window restore"

if [[ ! -f "$STATE_FILE" ]]; then
  log "No saved state file found at $STATE_FILE"
  exit 0
fi

log "Reading state from $STATE_FILE"

# Parse saved state into parallel arrays
# Each entry: bundle_id, title_pattern, workspace
declare -a saved_bundles=()
declare -a saved_patterns=()
declare -a saved_workspaces=()
declare -a satisfied=()

# Parse JSON entries (simple line-by-line parsing for our known format)
while IFS= read -r line; do
  # Extract fields from JSON line like:
  #   {"app-bundle-id": "com.foo", "title-pattern": "- Edge - NDS", "workspace": "3"}
  bundle=$(echo "$line" | sed -n 's/.*"app-bundle-id": "\([^"]*\)".*/\1/p')
  pattern=$(echo "$line" | sed -n 's/.*"title-pattern": "\([^"]*\)".*/\1/p')
  workspace=$(echo "$line" | sed -n 's/.*"workspace": "\([^"]*\)".*/\1/p')

  [[ -z "$bundle" ]] && continue
  [[ -z "$workspace" ]] && continue

  saved_bundles+=("$bundle")
  saved_patterns+=("$pattern")
  saved_workspaces+=("$workspace")
  satisfied+=(0)
done < "$STATE_FILE"

num_entries=${#saved_bundles[@]}
log "Loaded $num_entries saved entries"

if ((num_entries == 0)); then
  log "No entries to restore"
  exit 0
fi

# Handle entries with empty title-pattern: if the same bundle-id has an empty pattern,
# it means the app typically has one window. We need to handle the case where the
# empty-pattern entry is just a fallback for a single-window app.

SEP=$'\x1f'
elapsed=0
prev_window_count=0
stale_rounds=0

while ((elapsed < MAX_WAIT)); do
  # Get current windows
  window_data=$(aerospace list-windows --all --format "%{app-bundle-id}${SEP}%{window-title}${SEP}%{workspace}${SEP}%{window-id}")
  current_window_count=$(echo "$window_data" | wc -l | tr -d ' ')

  moves_this_round=0

  # For each saved entry that hasn't been satisfied yet
  for ((i=0; i<num_entries; i++)); do
    ((satisfied[i] == 1)) && continue

    target_bundle="${saved_bundles[$i]}"
    target_pattern="${saved_patterns[$i]}"
    target_workspace="${saved_workspaces[$i]}"

    # Find matching windows
    while IFS="$SEP" read -r win_bundle win_title win_workspace win_id; do
      [[ -z "$win_bundle" ]] && continue
      [[ "$win_bundle" != "$target_bundle" ]] && continue

      # Check title pattern match
      if [[ -n "$target_pattern" ]]; then
        # Must contain the pattern as a substring
        if [[ "$win_title" != *"$target_pattern"* ]]; then
          continue
        fi
      fi

      # Window matches this entry. Move it if not already on target workspace.
      if [[ "$win_workspace" != "$target_workspace" ]]; then
        log "Moving window $win_id ($win_bundle, pattern='$target_pattern') from ws $win_workspace to ws $target_workspace"
        aerospace move-node-to-workspace --window-id "$win_id" "$target_workspace" 2>> "$LOG_FILE" || true
        ((moves_this_round++))
      else
        log "Window $win_id ($win_bundle, pattern='$target_pattern') already on ws $target_workspace"
      fi

      satisfied[$i]=1
      break
    done <<< "$window_data"
  done

  # Check if all entries are satisfied
  all_done=1
  for ((i=0; i<num_entries; i++)); do
    if ((satisfied[i] == 0)); then
      all_done=0
      break
    fi
  done

  if ((all_done)); then
    log "All $num_entries entries restored successfully"
    break
  fi

  # Track if new windows appeared; if no new windows for several rounds, give up waiting
  if ((current_window_count == prev_window_count && moves_this_round == 0)); then
    ((stale_rounds++))
  else
    stale_rounds=0
  fi

  # After 5 stale rounds (10 seconds with no changes), stop waiting
  if ((stale_rounds >= 5)); then
    remaining=0
    for ((i=0; i<num_entries; i++)); do
      if ((satisfied[i] == 0)); then
        ((remaining++))
        log "Unsatisfied: ${saved_bundles[$i]} pattern='${saved_patterns[$i]}' -> ws ${saved_workspaces[$i]}"
      fi
    done
    log "Giving up after ${elapsed}s of no changes. $remaining entries unsatisfied."
    break
  fi

  prev_window_count=$current_window_count
  sleep "$POLL_INTERVAL"
  ((elapsed += POLL_INTERVAL))
done

# Final delay to let move events settle before releasing lock
sleep 2

# Count results
satisfied_count=0
for ((i=0; i<num_entries; i++)); do
  ((satisfied[i] == 1)) && ((satisfied_count++))
done
log "Restore complete: $satisfied_count/$num_entries entries restored in ${elapsed}s"

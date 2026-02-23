#!/bin/bash
# Combined workspace change handler:
# 1. Notify SketchyBar
# 2. Save workspace-monitor state for persistence (per monitor set)
# 3. Save window-to-workspace assignments (for app persistence across reboots)

LOG_FILE="$HOME/.local/state/aerospace/debug.log"
echo "[$(date)] on-workspace-change.sh triggered, workspace=$AEROSPACE_FOCUSED_WORKSPACE" >> "$LOG_FILE"

# 1. SketchyBar notification
if command -v sketchybar &>/dev/null; then
  sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$AEROSPACE_FOCUSED_WORKSPACE"
fi

# 2. Save workspace-monitor assignments (per monitor set)
STATE_DIR="$HOME/.local/state/aerospace"
LOCK_FILE="$STATE_DIR/restore.lock"
MONITOR_CACHE="$STATE_DIR/monitor-cache.txt"
mkdir -p "$STATE_DIR"

save_monitor_state() {
  # Skip saving if a monitor restore is in progress (prevents overwriting good state)
  if [[ -f "$LOCK_FILE" ]]; then
    echo "[$(date)] Skipping monitor save - restore in progress (lock file exists)" >> "$LOG_FILE"
    return
  fi

  # Also check if monitors have changed since last cache - if so, skip saving
  # This handles the race where we run before detect-monitor-change.sh creates the lock
  current_monitors=$(aerospace list-monitors --format '%{monitor-name}' | sort)
  if [[ -f "$MONITOR_CACHE" ]]; then
    cached_monitors=$(cat "$MONITOR_CACHE")
    if [[ "$current_monitors" != "$cached_monitors" ]]; then
      echo "[$(date)] Skipping monitor save - monitors changed (cache mismatch)" >> "$LOG_FILE"
      return
    fi
  fi

  # Generate unique ID from current monitor set
  # Sort monitor names, lowercase, replace spaces/special chars with dashes, join with underscore
  monitor_set_id=$(aerospace list-monitors --format '%{monitor-name}' | \
    sort | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9]/-/g' | \
    tr '\n' '_' | \
    sed 's/_$//')

  STATE_FILE="$STATE_DIR/workspace-monitors-${monitor_set_id}.json"

  # Build JSON manually without jq dependency
  {
    echo "{"
    aerospace list-workspaces --all --format '%{workspace}:%{monitor-name}' | \
      awk -F: 'NF==2 {printf "  \"%s\": \"%s\",\n", $1, $2}' | \
      sed '$ s/,$//'
    echo "}"
  } > "$STATE_FILE"

  echo "[$(date)] Saved monitor state to $STATE_FILE" >> "$LOG_FILE"
}

save_monitor_state

# 3. Save window-to-workspace assignments (has its own lock file check)
~/.config/aerospace/save-window-state.sh &

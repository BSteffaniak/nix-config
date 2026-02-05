#!/bin/bash
# Restore workspace-to-monitor assignments from saved state
# Uses monitor-set-specific state files (based on exact monitor names)
# NOTE: Lock file is created by detect-monitor-change.sh BEFORE calling this script

STATE_DIR="$HOME/.local/state/aerospace"
LOCK_FILE="$STATE_DIR/restore.lock"
LOG_FILE="$STATE_DIR/debug.log"

# Clean up lock file on exit (lock was created by detect-monitor-change.sh)
cleanup() {
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Generate unique ID from current monitor set
# Sort monitor names, lowercase, replace spaces/special chars with dashes, join with underscore
monitor_set_id=$(aerospace list-monitors --format '%{monitor-name}' | \
  sort | \
  tr '[:upper:]' '[:lower:]' | \
  sed 's/[^a-z0-9]/-/g' | \
  tr '\n' '_' | \
  sed 's/_$//')

STATE_FILE="$STATE_DIR/workspace-monitors-${monitor_set_id}.json"

echo "[$(date)] restore: looking for state file: $STATE_FILE" >> "$LOG_FILE"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "[$(date)] restore: No saved state for monitor set: $monitor_set_id" >> "$LOG_FILE"
  echo "No saved state for monitor set: $monitor_set_id"
  exit 0
fi

echo "[$(date)] restore: Reading state file contents:" >> "$LOG_FILE"
cat "$STATE_FILE" >> "$LOG_FILE"

# Get current monitors
current_monitors=$(aerospace list-monitors --format '%{monitor-name}')
echo "[$(date)] restore: Current monitors: $current_monitors" >> "$LOG_FILE"

# Parse JSON properly using awk - macOS sed doesn't support \s
while IFS= read -r line; do
  # Extract workspace and monitor from JSON line like:   "2": "Acer B286HK",
  # awk -F'"' splits on quotes: $2 is workspace, $4 is monitor
  workspace=$(echo "$line" | awk -F'"' '{print $2}')
  monitor=$(echo "$line" | awk -F'"' '{print $4}')
  
  # Skip empty
  [[ -z "$workspace" ]] && continue
  [[ -z "$monitor" ]] && continue
  
  echo "[$(date)] restore: Processing workspace=$workspace monitor=$monitor" >> "$LOG_FILE"
  
  # Check if the monitor exists
  if echo "$current_monitors" | grep -qF "$monitor"; then
    echo "[$(date)] restore: Moving workspace $workspace to $monitor" >> "$LOG_FILE"
    aerospace move-workspace-to-monitor --workspace "$workspace" "$monitor" 2>> "$LOG_FILE" || true
  else
    echo "[$(date)] restore: Monitor '$monitor' not found, skipping workspace $workspace" >> "$LOG_FILE"
  fi
done < <(grep -E '^\s*"[^"]+"\s*:\s*"[^"]+"' "$STATE_FILE")

# Delay to ensure all moves complete and workspace-change events fire before releasing lock
# This prevents on-workspace-change.sh from saving intermediate state
sleep 2

echo "Workspace-monitor assignments restored for: $monitor_set_id"

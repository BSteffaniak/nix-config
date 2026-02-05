#!/bin/bash
# Detect monitor changes on focus change and restore workspace assignments
# Runs on every focus change, but only triggers restore when monitors actually change

LOG_FILE="$HOME/.local/state/aerospace/debug.log"
STATE_DIR="$HOME/.local/state/aerospace"
MONITOR_CACHE="$STATE_DIR/monitor-cache.txt"
LOCK_FILE="$STATE_DIR/restore.lock"
mkdir -p "$STATE_DIR"

# Get current monitors (sorted for consistent comparison)
current_monitors=$(aerospace list-monitors --format '%{monitor-name}' | sort)

# Read cached monitors
if [[ -f "$MONITOR_CACHE" ]]; then
  cached_monitors=$(cat "$MONITOR_CACHE")
else
  cached_monitors=""
fi

# Compare
if [[ "$current_monitors" != "$cached_monitors" ]]; then
  # Monitors changed! Create lock IMMEDIATELY to prevent saves during transition
  echo $$ > "$LOCK_FILE"
  
  echo "[$(date)] Monitor change detected" >> "$LOG_FILE"
  echo "  cached: $cached_monitors" >> "$LOG_FILE"
  echo "  current: $current_monitors" >> "$LOG_FILE"
  
  echo "$current_monitors" > "$MONITOR_CACHE"
  
  # Only restore if we had a previous state (not first run after boot)
  if [[ -n "$cached_monitors" ]]; then
    echo "[$(date)] Triggering restore..." >> "$LOG_FILE"
    ~/.config/aerospace/restore-workspace-monitors.sh >> "$LOG_FILE" 2>&1 &
  else
    echo "[$(date)] No cached monitors, skipping restore" >> "$LOG_FILE"
    # Still hold lock briefly to let any in-flight saves complete, then release
    sleep 1
    rm -f "$LOCK_FILE"
  fi
fi

#!/usr/bin/env bash
# Window fuzzy finder for AeroSpace using choose
# Displays all windows and focuses the selected one

set -euo pipefail

# Get all windows in JSON format
windows_json=$(aerospace list-windows --all --json 2>/dev/null)

if [[ -z "$windows_json" || "$windows_json" == "[]" ]]; then
    exit 0
fi

# Parse JSON and create display lines: "app-name | window-title"
# Store window IDs for lookup
declare -a window_ids
declare -a display_lines

while IFS= read -r line; do
    window_id=$(echo "$line" | jq -r '.["window-id"]')
    app_name=$(echo "$line" | jq -r '.["app-name"]')
    window_title=$(echo "$line" | jq -r '.["window-title"]')
    workspace=$(echo "$line" | jq -r '.workspace')
    
    # Truncate long titles
    if [[ ${#window_title} -gt 60 ]]; then
        window_title="${window_title:0:57}..."
    fi
    
    display_line="[$workspace] $app_name: $window_title"
    window_ids+=("$window_id")
    display_lines+=("$display_line")
done < <(echo "$windows_json" | jq -c '.[]')

# If no windows, exit
if [[ ${#display_lines[@]} -eq 0 ]]; then
    exit 0
fi

# Create input for choose (newline-separated)
input=""
for line in "${display_lines[@]}"; do
    input+="$line"$'\n'
done
input="${input%$'\n'}"  # Remove trailing newline

# Run choose and get selection
selected=$(echo "$input" | choose)

# If user cancelled, exit
if [[ -z "$selected" ]]; then
    exit 0
fi

# Find the index of the selected line
selected_index=-1
for i in "${!display_lines[@]}"; do
    if [[ "${display_lines[$i]}" == "$selected" ]]; then
        selected_index=$i
        break
    fi
done

# Focus the selected window
if [[ $selected_index -ge 0 ]]; then
    window_id="${window_ids[$selected_index]}"
    aerospace focus --window-id "$window_id"
fi

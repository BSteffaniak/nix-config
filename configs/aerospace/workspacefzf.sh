#!/usr/bin/env bash
# Workspace fuzzy finder for AeroSpace using choose
# Displays all workspaces with window counts and switches to the selected one

set -euo pipefail

# Get current workspace
current_workspace=$(aerospace list-workspaces --focused 2>/dev/null || echo "")

# Get all workspaces and their windows
all_workspaces=$(aerospace list-workspaces --all 2>/dev/null)

if [[ -z "$all_workspaces" ]]; then
    exit 0
fi

# Build display lines with window counts
declare -a display_lines
declare -a workspace_names

while IFS= read -r ws; do
    [[ -z "$ws" ]] && continue
    
    # Get windows in this workspace
    windows=$(aerospace list-windows --workspace "$ws" --json 2>/dev/null || echo "[]")
    window_count=$(echo "$windows" | jq 'length')
    
    # Get first few app names for preview
    app_preview=""
    if [[ "$window_count" -gt 0 ]]; then
        app_preview=$(echo "$windows" | jq -r '.[0:3] | .[].["app-name"]' | tr '\n' ', ' | sed 's/, $//')
        if [[ "$window_count" -gt 3 ]]; then
            app_preview="$app_preview, ..."
        fi
    fi
    
    # Mark current workspace
    if [[ "$ws" == "$current_workspace" ]]; then
        marker="*"
    else
        marker=" "
    fi
    
    if [[ -n "$app_preview" ]]; then
        display_line="$marker Workspace $ws ($window_count): $app_preview"
    else
        display_line="$marker Workspace $ws (empty)"
    fi
    
    workspace_names+=("$ws")
    display_lines+=("$display_line")
done <<< "$all_workspaces"

# If no workspaces, exit
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

# Switch to the selected workspace
if [[ $selected_index -ge 0 ]]; then
    workspace="${workspace_names[$selected_index]}"
    aerospace workspace "$workspace"
fi

#!/usr/bin/env bash

# Format all Nix files in the repository using nixfmt
# Usage: ./fmt.sh [--check]

set -euo pipefail

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Parse arguments
CHECK_MODE=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if nixfmt is available
if ! command -v nixfmt &> /dev/null; then
  echo -e "${RED}Error: nixfmt not found in PATH${NC}"
  echo "Install it with: nix-shell -p nixfmt-rfc-style"
  exit 1
fi

echo "Searching for Nix files..."

# Find all .nix files, excluding:
# - .git directory
# - result symlinks
# - Any nix store paths
# Use mapfile to properly read into an array
mapfile -t FILES < <(find "$SCRIPT_DIR" -type f -name "*.nix" \
  -not -path "*/\.git/*" \
  -not -path "*/result*" \
  -not -path "*/nix/store/*" | sort)

FILE_COUNT=${#FILES[@]}

echo -e "Found ${BLUE}$FILE_COUNT${NC} Nix files to process"
echo ""

if [[ "$CHECK_MODE" == true ]]; then
  echo -e "${YELLOW}Running in CHECK mode (no files will be modified)${NC}"
  echo ""
fi

# Track statistics
FORMATTED=0
ALREADY_FORMATTED=0
FAILED=0
FAILED_FILES=()

# Process each file using array iteration
for file in "${FILES[@]}"; do
  # Skip empty entries
  [[ -z "$file" ]] && continue

  # Get relative path for display
  rel_path="${file#$SCRIPT_DIR/}"

  # Skip binary/encrypted files (e.g., git-crypt locked files)
  if file --mime-encoding "$file" 2>/dev/null | grep -q "binary"; then
    echo -e "${YELLOW}⊘${NC} Skipped (encrypted): $rel_path"
    continue
  fi

  if [[ "$CHECK_MODE" == true ]]; then
    # Check mode: verify if file is formatted
    if nixfmt --check "$file" &> /dev/null; then
      echo -e "${GREEN}✓${NC} $rel_path"
      ALREADY_FORMATTED=$((ALREADY_FORMATTED + 1))
    else
      echo -e "${YELLOW}✗${NC} $rel_path (needs formatting)"
      FORMATTED=$((FORMATTED + 1))
    fi
  else
    # Format mode: actually format the file
    if nixfmt "$file" &> /dev/null; then
      echo -e "${GREEN}✓${NC} Formatted: $rel_path"
      FORMATTED=$((FORMATTED + 1))
    else
      echo -e "${RED}✗${NC} Failed: $rel_path"
      FAILED=$((FAILED + 1))
      FAILED_FILES+=("$rel_path")
    fi
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"

if [[ "$CHECK_MODE" == true ]]; then
  echo -e "  Already formatted: ${GREEN}$ALREADY_FORMATTED${NC} files"
  echo -e "  Need formatting:   ${YELLOW}$FORMATTED${NC} files"
  echo -e "  Total checked:     ${BLUE}$FILE_COUNT${NC} files"

  if [[ $FORMATTED -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}⚠  Some files need formatting. Run './fmt.sh' to format them.${NC}"
    exit 1
  else
    echo ""
    echo -e "${GREEN}✓ All files are properly formatted!${NC}"
    npx prettier "**/*.{md,yml,yaml,ts,json,css,js}"
    exit 0
  fi
else
  echo -e "  Formatted:  ${GREEN}$FORMATTED${NC} files"
  echo -e "  Failed:     ${RED}$FAILED${NC} files"
  echo -e "  Total:      ${BLUE}$FILE_COUNT${NC} files"

  if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed to format:${NC}"
    for failed_file in "${FAILED_FILES[@]}"; do
      echo "  - $failed_file"
    done
    exit 1
  else
    echo ""
    echo -e "${GREEN}✓ Successfully formatted all files!${NC}"
    npx prettier --write "**/*.{md,yml,yaml,ts,json,css,js}"
    exit 0
  fi
fi

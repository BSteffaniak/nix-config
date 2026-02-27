# Commit Message Shared Instructions

## Gathering Changes

1. Determine what changed:
   - Run `git diff --cached --stat` to check for staged changes
   - If there are staged changes, use `git diff --cached` for the full diff
   - If nothing is staged, use `git diff` for unstaged changes instead
   - If both are empty, inform the user there is nothing to commit
2. Optionally run `git log --oneline -10` to see recent commit style for context
3. Analyze the diff carefully — understand the specific, concrete changes

## Commit Message Rules

### Title

- Imperative mood ("Add", "Fix", "Remove", "Update", "Refactor", not "Added", "Fixes", "Removed")
- ~50 characters, 72 max
- No period at the end
- Specific to WHAT changed — name the actual thing (function, module, endpoint, component, file)

### Description

- Blank line between title and description
- Wrap at 72 characters
- Bullet points or short paragraph
- Describe WHAT the changes are, not WHY
- Be specific: name files, functions, config keys, endpoints, flags — whatever was actually touched
- Multiple logical changes should each get their own bullet

### Strictly Forbidden

- Generic messages: "Update code", "Fix bugs", "Code review changes", "Address feedback", "Make improvements", "Various updates", "Clean up"
- Describing motivation or reasoning — the commit message is the WHAT, the PR description is the WHY
- Repeating the title in the description
- Meaningless filler like "This commit..." or "Changes include..."

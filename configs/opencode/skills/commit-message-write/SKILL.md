---
name: commit-message-write
description: Generate a git commit message and write it so it's pre-filled when you run `git commit` or press `c` in lazygit.
allowed-tools: Bash(git:*)
---

## Purpose

Generate a commit message for the current staged or unstaged changes, and write it to the repo so it's automatically pre-filled in both:

- `git commit` (via the `prepare-commit-msg` hook reading `PREPARED_MSG`)
- lazygit's commit panel (via `LAZYGIT_PENDING_COMMIT`)

## Steps

1. Determine what changed:
   - Run `git diff --cached --stat` to check for staged changes
   - If there are staged changes, use `git diff --cached` for the full diff
   - If nothing is staged, use `git diff` for unstaged changes instead
   - If both are empty, inform the user there is nothing to commit
2. Optionally run `git log --oneline -10` to see recent commit style for context
3. Analyze the diff carefully — understand the specific, concrete changes
4. Compose the commit message following the rules below
5. Write the message to both prepared message files:
   ```bash
   git_dir=$(git rev-parse --git-dir)
   # Write the commit message to BOTH files:
   # - $git_dir/PREPARED_MSG (for git commit via prepare-commit-msg hook)
   # - $git_dir/LAZYGIT_PENDING_COMMIT (for lazygit's commit panel pre-fill)
   ```
6. Display the message to the user and tell them:
   - Run `git commit` — the message will be pre-filled in your editor
   - Or press `c` in lazygit — the commit panel will have the message pre-filled
   - Files are cleaned up automatically after a successful commit

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

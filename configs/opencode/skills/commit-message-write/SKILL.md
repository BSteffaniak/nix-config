---
name: commit-message-write
description: Generate a git commit message and write it to .git/PREPARED_MSG so it's pre-filled in your editor when you run `git commit`.
allowed-tools: Bash(git:*)
---

## Purpose

Generate a commit message for the current staged or unstaged changes, write it to the repo's `.git/PREPARED_MSG` file so the `prepare-commit-msg` hook automatically pre-fills it in the editor when the user runs `git commit`.

## Steps

1. Determine what changed:
   - Run `git diff --cached --stat` to check for staged changes
   - If there are staged changes, use `git diff --cached` for the full diff
   - If nothing is staged, use `git diff` for unstaged changes instead
   - If both are empty, inform the user there is nothing to commit
2. Optionally run `git log --oneline -10` to see recent commit style for context
3. Analyze the diff carefully — understand the specific, concrete changes
4. Compose the commit message following the rules below
5. Write the message to the prepared message file:
   ```bash
   git_dir=$(git rev-parse --git-dir)
   # Write the commit message to $git_dir/PREPARED_MSG
   ```
6. Display the message to the user and tell them:
   - Run `git commit` — the message will be pre-filled in your editor
   - The `prepare-commit-msg` hook reads `PREPARED_MSG` and injects it automatically
   - The file is consumed on use (one-shot), so it won't affect future commits

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

---
name: commit-message-write
description: Generate a git commit message and write it to .git/COMMIT_MSG so you can commit with it pre-filled in your editor.
allowed-tools: Bash(git:*)
---

## Purpose

Generate a commit message for the current staged or unstaged changes, write it to the repo's `.git/COMMIT_MSG` file, and provide the command to commit with it.

## Steps

1. Determine what changed:
   - Run `git diff --cached --stat` to check for staged changes
   - If there are staged changes, use `git diff --cached` for the full diff
   - If nothing is staged, use `git diff` for unstaged changes instead
   - If both are empty, inform the user there is nothing to commit
2. Optionally run `git log --oneline -10` to see recent commit style for context
3. Analyze the diff carefully — understand the specific, concrete changes
4. Compose the commit message following the rules below
5. Write the message to the git commit message file:
   ```bash
   git_dir=$(git rev-parse --git-dir)
   # Write the commit message to $git_dir/COMMIT_MSG
   ```
6. Display the message to the user AND provide the ready-to-run command:
   ```
   git commit -e -F "$(git rev-parse --git-dir)/COMMIT_MSG"
   ```
   Explain that `-e` opens their editor so they can review/edit before finalizing, and `-F` pre-fills it with the generated message.

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

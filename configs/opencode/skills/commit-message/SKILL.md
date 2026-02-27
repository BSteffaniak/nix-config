---
name: commit-message
description: Generate a specific, well-crafted git commit message (title and description) for the current changes. Read-only — prints the message for you to copy.
allowed-tools: Bash(git:*)
---

## Purpose

Generate a commit message for the current staged or unstaged changes. Output the message as text for the user to copy. Do not run `git commit` or write any files.

## Steps

1. Determine what changed:
   - Run `git diff --cached --stat` to check for staged changes
   - If there are staged changes, use `git diff --cached` for the full diff
   - If nothing is staged, use `git diff` for unstaged changes instead
   - If both are empty, inform the user there are nothing to commit
2. Optionally run `git log --oneline -10` to see recent commit style for context
3. Analyze the diff carefully — understand the specific, concrete changes
4. Output a commit message in this exact format:

```
<title>

<description>
```

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

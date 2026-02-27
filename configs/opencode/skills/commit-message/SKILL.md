---
name: commit-message
description: Generate a specific, well-crafted git commit message (title and description) for the current changes. Read-only — prints the message for you to copy.
allowed-tools: Bash(git:*)
---

## Purpose

Generate a commit message for the current staged or unstaged changes. Output the message as text for the user to copy. Do not run `git commit` or write any files.

## Steps

Follow the [Gathering Changes](../_shared/commit-rules.md#gathering-changes) steps, then:

4. Output a commit message in this exact format:

```
<title>

<description>
```

## Rules

Follow the [Commit Message Rules](../_shared/commit-rules.md#commit-message-rules) strictly.

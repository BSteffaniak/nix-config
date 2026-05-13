---
name: commit-message-staged
description: Generate a commit message from staged changes only. Read-only — prints the message for you to copy.
allowed-tools: Bash(git:*)
---

## Purpose

Generate a commit message from currently staged changes ONLY. Output the message as text for the user to copy. Do not run `git commit` or write any files. Do not consider unstaged changes.

## Steps

Follow the [Gathering Staged Changes](../_shared/commit-rules-staged.md#gathering-staged-changes) steps, then:

4. Output a commit message in this exact format:

```
<title>

<description>
```

## Rules

Follow the [Commit Message Rules](../_shared/commit-rules.md#commit-message-rules) strictly.

---
name: pr-description-write
description: Generate a PR title and description for the current branch and write it to a temp file.
allowed-tools: Bash(git:*), Bash(mktemp:*), Write(*)
---

## Purpose

Generate a PR title and description for the current branch's changes, and write it to a temporary file.

## Steps

Follow the [Gathering Branch Changes](../_shared/pr-description-rules.md#gathering-branch-changes) steps, then:

4. Analyze the branch-only commits and diff carefully
5. Compose the PR description following the [PR Description Format](../_shared/pr-description-rules.md#pr-description-format)
6. Write the description to a cross-platform temp file:
   ```bash
   tmpfile=$(mktemp "${TMPDIR:-/tmp}/pr-description-XXXXXX.md")
   ```
7. Display the PR description to the user and tell them the file path

## Rules

Follow the rules in [Strictly Forbidden](../_shared/pr-description-rules.md#strictly-forbidden).

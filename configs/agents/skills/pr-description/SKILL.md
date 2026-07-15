---
name: pr-description
description: Generate a PR title and description for the current branch's changes. Read-only — prints the markdown for you to copy.
allowed-tools: Bash(git:*)
---

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` or `gh` invocation. These rules are mandatory even when an example below omits the environment prefix for brevity.

## Purpose

Generate a PR title and description for the current branch. Output as markdown text for the user to copy. Do not write any files.

## Steps

Follow the [Gathering Branch Changes](../_shared/pr-description-rules.md#gathering-branch-changes) steps, then:

4. Analyze the branch-only commits and diff carefully
5. Output the PR description following the [PR Description Format](../_shared/pr-description-rules.md#pr-description-format)

## Rules

Follow the rules in [Strictly Forbidden](../_shared/pr-description-rules.md#strictly-forbidden).

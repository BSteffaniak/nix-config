---
name: commit-message
description: Generate a specific, well-crafted git commit message (title and description) for the current changes. Read-only — prints the message for you to copy.
allowed-tools: Bash(git:*)
---

## User overrides

Follow the [shared user override contract](../_shared/user-overrides.md). This skill's gates describe the default workflow, but a direct, explicit user instruction may change or skip them within the scope the user authorizes. This section takes precedence over conflicting gate or approval language elsewhere in this skill.

## Command execution

**Never invoke bare `git`.** Every Git invocation must include the global
`--no-pager` option before the subcommand: `git --no-pager …`. This applies
inside scripts, command substitutions, pipelines, and compound commands.
Before submitting a shell command, check every Git invocation. Piping output
or expecting short output is not a substitute; pagers can hang until timeout.

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` or `gh` invocation. These rules are mandatory even when an example below omits the environment prefix for brevity.

## Purpose

Generate a commit message for the current staged or unstaged changes. Output the
message as text for the user to copy. Do not run `git commit` or write any
files.

## Steps

Follow the [Gathering Changes](../_shared/commit-rules.md#gathering-changes) steps, then:

4. Output a commit message in this exact format:

```
<title>

<description>
```

## Rules

Follow the [Commit Message Rules](../_shared/commit-rules.md#commit-message-rules) strictly.

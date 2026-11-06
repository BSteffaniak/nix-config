---
name: commit-message-bcode-git-write
description: Generate a git commit message and write it so it's pre-filled when you press `c` in bcode-git.
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

Generate a commit message for the current staged or unstaged changes, and write
it to the repo so it's automatically pre-filled for bcode-git's commit panel via
`BCODE_GIT_COMMIT_MSG`.

## Steps

Follow the [Gathering Changes](../_shared/commit-rules.md#gathering-changes) steps, then:

4. Compose the commit message following the [Commit Message Rules](../_shared/commit-rules.md#commit-message-rules)
5. Write the message to the bcode-git pending commit file:
   ```bash
   git_dir=$(git --no-pager rev-parse --git-dir)
   # Write the commit message to:
   # - $git_dir/BCODE_GIT_COMMIT_MSG (for bcode-git's commit panel pre-fill)
   ```
6. Respond tersely that the file was written. Do not display the generated commit message. Do not include extra explanation unless there is an error.

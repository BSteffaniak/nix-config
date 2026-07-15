---
name: commit-message-staged-lazygit-write
description: Generate a commit message from staged changes only and write it so it's pre-filled when you press `c` in lazygit.
allowed-tools: Bash(git:*)
---

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` or `gh` invocation. These rules are mandatory even when an example below omits the environment prefix for brevity.

## Purpose

Generate a commit message from currently staged changes ONLY, and write it to the repo so it's automatically pre-filled for lazygit's commit panel via `LAZYGIT_PENDING_COMMIT`.

Do not consider unstaged changes.

## Steps

Follow the [Gathering Staged Changes](../_shared/commit-rules-staged.md#gathering-staged-changes) steps, then:

4. Compose the commit message following the [Commit Message Rules](../_shared/commit-rules.md#commit-message-rules)
5. Write the message to the lazygit pending commit file:
   ```bash
   git_dir=$(git rev-parse --git-dir)
   # Write the commit message to:
   # - $git_dir/LAZYGIT_PENDING_COMMIT (for lazygit's commit panel pre-fill)
   ```
6. Respond tersely that the file was written. Do not display the generated commit message. Do not include extra explanation unless there is an error.

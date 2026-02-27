---
name: commit-message-write
description: Generate a git commit message and write it so it's pre-filled when you run `git commit` or press `c` in lazygit.
allowed-tools: Bash(git:*)
---

## Purpose

Generate a commit message for the current staged or unstaged changes, and write it to the repo so it's automatically pre-filled in both:

- `git commit` (via the `prepare-commit-msg` hook reading `PREPARED_MSG`)
- lazygit's commit panel (via `LAZYGIT_PENDING_COMMIT`)

## Steps

Follow the [Gathering Changes](../_shared/commit-rules.md#gathering-changes) steps, then:

4. Compose the commit message following the [Commit Message Rules](../_shared/commit-rules.md#commit-message-rules)
5. Write the message to both prepared message files:
   ```bash
   git_dir=$(git rev-parse --git-dir)
   # Write the commit message to BOTH files:
   # - $git_dir/PREPARED_MSG (for git commit via prepare-commit-msg hook)
   # - $git_dir/LAZYGIT_PENDING_COMMIT (for lazygit's commit panel pre-fill)
   ```
6. Display the message to the user and tell them:
   - Run `git commit` — the message will be pre-filled in your editor
   - Or press `c` in lazygit — the commit panel will have the message pre-filled
   - Files are cleaned up automatically after a successful commit

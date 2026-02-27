# Commit Message Shared Instructions (Staged Only)

## Gathering Staged Changes

1. Run `git diff --cached --stat` to check for staged changes
2. If nothing is staged, inform the user there are no staged changes to generate a message for — do NOT fall back to unstaged changes
3. Use `git diff --cached` for the full diff
4. Optionally run `git log --oneline -10` to see recent commit style for context
5. Analyze the diff carefully — understand the specific, concrete changes

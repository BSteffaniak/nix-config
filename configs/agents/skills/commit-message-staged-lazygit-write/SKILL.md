---
name: commit-message-staged-lazygit-write
description: Generate a commit message from staged changes and write it to lazygit's pending commit message file with minimal tool calls.
allowed-tools: Bash(bash:*), Bash(git:*)
---

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` or `gh` invocation.

## Purpose

Generate a commit message from currently staged changes only and write it to
`LAZYGIT_PENDING_COMMIT` so lazygit pre-fills its commit panel.

Optimize for a fast, single-turn workflow. In the normal case, gather all Git
context with the bundled script in one tool call, generate the message, and
write it in one more tool call. Do not ask questions or perform separate
inspection calls unless the gathered context is genuinely insufficient.

## Steps

### 1. Gather context

From the repository being committed, run the bundled script once:

```bash
bash <skill-directory>/scripts/gather-context.sh
```

Resolve `<skill-directory>` as the directory containing this `SKILL.md`.

The script verifies that staged changes exist and prints:

- The Git directory to receive `LAZYGIT_PENDING_COMMIT`
- Recent commit subjects for repository style
- The staged diff stat
- The complete staged diff

If it reports that nothing is staged, tell the user and stop. Never fall back
to unstaged changes.

### 2. Generate the message

Generate the commit message directly from the script output. Follow the
[Commit Message Rules](../_shared/commit-rules.md#commit-message-rules).

Do not make more tool calls merely to gather the same context in a different
form. Additional inspection is appropriate only when the script output is
insufficient to identify the staged change accurately, such as:

- Tool output was truncated
- The diff primarily contains generated or binary content
- A submodule pointer changed without enough identifying context
- The semantic purpose cannot be inferred from the diff
- Conflicting evidence makes an accurate message uncertain

When more context is required, inspect only the specific staged files or Git
metadata needed to resolve the uncertainty. Ask the user a concise question
only when targeted inspection cannot resolve it.

### 3. Write the message

Using the Git directory printed by the context script, write the generated
message to `<git-directory>/LAZYGIT_PENDING_COMMIT` in one tool call. Preserve
the message exactly, including its blank line and wrapped body.

Do not create a commit, stage files, or alter the index. Invocation of this
skill authorizes replacing only the pending commit message file.

### 4. Report completion

Respond tersely that the lazygit pending commit message was written. Do not
display the message or add explanation unless an error occurred.

## Rules

- **Staged changes only.** Never inspect, describe, or fall back to unstaged changes.
- **Prefer the two-call fast path.** Normally use one call for context and one call to write the message.
- **Probe only when necessary.** Additional calls must resolve a concrete insufficiency in the gathered context.
- **Avoid normal-path interaction.** Do not ask for confirmation or clarification when the staged diff is sufficient.
- **Do not commit.** Only replace `LAZYGIT_PENDING_COMMIT`; never run `git commit`.
- **Preserve message quality.** Token efficiency must not override the shared commit-message rules or factual accuracy.
- **Fail clearly.** Stop with a concise explanation when outside a repository, when nothing is staged, or when writing fails.

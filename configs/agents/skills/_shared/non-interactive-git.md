# Non-Interactive Git and GitHub Commands

Apply these rules to every shell invocation that uses `git` or `gh`.

## Required behavior

- Commands must complete without terminal interaction. Never rely on a pager, editor, browser, selector, confirmation prompt, credential prompt, or other TTY input.
- **Never invoke bare `git`.** Every Git invocation must include the global `--no-pager` option before the subcommand: `git --no-pager ...`. This applies inside scripts, command substitutions, pipelines, and compound commands. Before submitting a shell command, check every Git invocation. Piping output or expecting short output is not a substitute: a pager can hang until timeout.
- Bundled scripts should also export `GIT_PAGER=cat PAGER=cat GIT_TERMINAL_PROMPT=0` as defense in depth. Keep explicit `--no-pager` on every invocation. Exports protect only that script and its children, not later independent tool calls; do not change the user's interactive Git pager configuration.
- Run GitHub CLI commands with `GH_PAGER=cat` and `GH_PROMPT_DISABLED=1` in the command environment.
- Set `GIT_TERMINAL_PROMPT=0` whenever Git could contact a remote. If credentials are unavailable, stop and report the authentication problem instead of waiting for input.
- Do not use interactive command modes or flags, including `git add -p`, `git add -i`, `git rebase -i`, `git commit` without `-m`/`-F`, `git mergetool`, or `gh ... --web`.
- Prefer bounded or machine-readable output where available: `-n`, `--stat`, `--name-only`, `--format`, `--json`, and `--jq`.
- Do not pipe output to an interactive pager such as `less` or `more`. Use non-interactive filters only when needed.
- If a required operation has no safe non-interactive form, ask the user to perform it manually rather than launching it.

`gh api --paginate` is allowed when needed: it paginates API responses and does
not launch a terminal pager.

## Examples

```bash
git --no-pager status --short --branch
git --no-pager diff --stat
git --no-pager log -n 10 --oneline
GIT_TERMINAL_PROMPT=0 git --no-pager fetch --dry-run
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr view 123 --json number,title,url
```

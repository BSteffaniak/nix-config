#!/usr/bin/env bash
set -euo pipefail

# Defense in depth for this script and its children, not later tool calls.
export GIT_PAGER=cat PAGER=cat GIT_TERMINAL_PROMPT=0

if ! git_dir=$(git --no-pager rev-parse --git-dir 2>/dev/null); then
	printf 'error: not inside a Git repository\n' >&2
	exit 2
fi

if git --no-pager diff --cached --quiet; then
	printf 'error: no staged changes\n' >&2
	exit 3
fi

printf '%s\n' '--- GIT DIRECTORY ---'
printf '%s\n' "$git_dir"

printf '\n%s\n' '--- RECENT COMMIT SUBJECTS ---'
if git --no-pager rev-parse --verify HEAD >/dev/null 2>&1; then
	git --no-pager log -10 --format='%h %s'
else
	printf '%s\n' '(no commits yet)'
fi

printf '\n%s\n' '--- STAGED DIFF STAT ---'
git --no-pager diff --cached --stat --no-ext-diff

printf '\n%s\n' '--- STAGED DIFF ---'
git --no-pager diff --cached --no-ext-diff

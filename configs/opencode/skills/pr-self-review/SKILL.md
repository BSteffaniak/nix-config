---
name: pr-self-review
description: Review your own pull request to find issues and produce a prioritized fix plan without posting GitHub comments.
allowed-tools: Bash(gh:*), Bash(git:*), Read(*)
---

## Purpose

Review your own pull request before external review. Analyze the full PR delta, identify concrete issues and risks, and return a prioritized plan of fixes. This skill is strictly internal: it never drafts comments and never submits anything to GitHub.

## Steps

### 1. Determine PR context

Resolve the target PR and review depth.

- If the user provides a PR URL, parse `owner/repo` and PR number from `github.com/{owner}/{repo}/pull/{number}`.
- If the user provides a PR number only, resolve repository from current directory:
  ```bash
  gh repo view --json nameWithOwner --jq .nameWithOwner
  ```
- If the user provides neither, auto-detect from the current branch:
  ```bash
  gh pr view --json number,url,title,headRefName,baseRefName
  ```

Parse depth:

- `--quick` or "quick self-review" -> quick mode (diff and immediate context)
- `--deep` or no flag -> deep mode (default, full context)

Determine local vs remote context:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null
```

- If current repo matches the PR repo, use `local` context and read files from the checkout.
- If it does not match, use `remote` context and read files via GitHub API.

If no PR can be resolved, stop and clearly report what is missing.

### 2. Gather PR data

Collect all inputs needed for a full self-review.

```bash
gh pr view {number} -R {owner}/{repo} --json number,url,title,body,author,headRefName,baseRefName,headRefOid,additions,deletions,changedFiles
gh pr diff {number} -R {owner}/{repo}
gh pr diff {number} -R {owner}/{repo} --name-only
gh pr view {number} -R {owner}/{repo} --json commits
```

Review all commits in scope, not only the latest commit.

### 3. Read changed code with context

For each changed file:

- Quick mode: review diff hunks and about 10-15 lines around each hunk.
- Deep mode: read full changed files (or relevant sections for very large files), then read key imports/types and one-hop related callers/callees where needed.

Context source rules:

- `local`: read files directly from local checkout.
- `remote`: read files via GitHub API; do not clone:
  ```bash
  gh api "repos/{owner}/{repo}/contents/{path}?ref={headRefName}" --jq '.content' | base64 -d
  ```

### 4. Identify findings

Evaluate changes across these categories:

- `bug`
- `security`
- `performance`
- `error-handling`
- `logic`
- `test-gap`
- `maintainability`

Severity levels:

- `blocking`: likely incorrect behavior, data risk, or security risk; must fix before merge
- `suggestion`: meaningful risk reduction or quality improvement; should fix
- `nit`: optional low-impact cleanup

For each finding include:

- severity and category
- evidence (`path:line`)
- why it matters
- minimal fix direction

Only report findings verified against real code context.

### 5. Build a prioritized fix plan

Convert findings into an implementation sequence:

1. blocking fixes first
2. suggestion-level fixes next
3. optional nits last

Each fix item should include:

- target file(s)
- expected code change
- dependency ordering notes
- verification commands (for example `bun run test`, `bun run type-check`, `bun run lint`, or package-scoped equivalents)

### 6. Return structured output

Return results in this order:

- PR context (title, scope, depth, changed-file summary)
- prioritized findings
- prioritized fix plan
- validation checklist

Keep output execution-oriented and internal. Do not draft reviewer comments.

## Rules

- **Never post to GitHub.** Do not create comments, reviews, or thread replies.
- **Read-only self-review workflow.** This skill analyzes and plans; it does not edit code.
- **Review full PR scope.** Analyze all commits and changed files in the PR delta.
- **Evidence is required.** Every non-trivial finding must cite concrete file and line evidence.
- **Do not inflate severity.** Use `blocking` only for genuine merge-stopping risk.
- **Skip style-only noise.** Avoid nits unless they have practical impact.
- **Be actionable.** Every `blocking` and `suggestion` finding must include a concrete fix direction.
- **Be explicit when clean.** If no meaningful issues are found, say so and list areas checked.

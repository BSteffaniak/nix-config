---
name: code-scanning-address
description: Address GitHub code scanning alerts. Interactive - fetches open alerts, triages each finding, and with approval applies code fixes and/or dismisses invalid alerts.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Read(*), Glob(*), Grep(*), Edit(*), Question(*)
---

## Purpose

Address GitHub Code Scanning findings end-to-end: fetch open alerts, analyze alert context in code, classify each finding, and then (with explicit user approval per alert) either apply a fix in the codebase or dismiss the alert with a documented rationale.

## Steps

### 1. Resolve target context

Determine which repository and alert set to process.

- Accept optional input:
  - GitHub repo URL (`https://github.com/owner/repo`)
  - `owner/repo`
  - default: current repo from `gh repo view`
- Optional filters:
  - severity (`critical|high|medium|low`)
  - tool (`CodeQL` default)
  - state (`open` default)
- Verify GitHub auth first:
  ```bash
  gh auth status
  ```

If repo context cannot be resolved, stop and request a valid repo reference.

### 2. Fetch open code scanning alerts

Fetch and summarize alert inventory.

```bash
gh api --paginate "repos/{owner}/{repo}/code-scanning/alerts?state=open&tool_name=CodeQL&per_page=100"
```

For each alert, capture:

- alert number
- rule id
- severity/security severity
- path + line
- message text
- alert URL

Present a grouped overview by rule and severity before any action.

### 3. Enrich each alert with evidence

For each alert in scope, fetch details and instance context:

```bash
gh api "repos/{owner}/{repo}/code-scanning/alerts/{number}"
gh api "repos/{owner}/{repo}/code-scanning/alerts/{number}/instances?per_page=100"
```

Then read local code context around the flagged location (`Read`, `Grep`, `Glob`) and classify into one of:

- **fix-now** - clear, low-risk, localized remediation
- **needs-design** - valid issue but requires non-trivial behavior/API decisions
- **likely-false-positive** - query heuristic likely over-tainting / low-signal finding
- **insufficient-context** - needs additional input from user/reviewer

### 4. Per-alert review gate (one at a time)

For each alert, present:

- rule + severity + message
- evidence (file path, line, relevant snippet context)
- proposed action and rationale
- blast radius estimate (small/medium/high)

Ask:

- **Apply fix**
- **Dismiss alert**
- **Defer (leave open)**
- **Skip**

Use `Question(*)` and process alerts strictly one-by-one.

### 5. Apply-fix path (only after approval)

If user chooses **Apply fix**:

1. Apply minimal targeted edit(s) with `Edit(*)`.
2. Show concise diff summary (`git diff -- <files>`).
3. Ask user to approve keeping the patch.

Do not auto-commit or push.
Do not claim validation unless checks were actually run.

### 6. Dismiss path (only after approval)

If user chooses **Dismiss alert**:

1. Require dismissal reason:
   - `false positive`
   - `won't fix`
   - `used in tests`
2. Draft a concise evidence-backed dismissal comment.
3. Confirm with user, then dismiss:

```bash
gh api -X PATCH "repos/{owner}/{repo}/code-scanning/alerts/{number}" \
  -f state='dismissed' \
  -f dismissed_reason='{reason}' \
  -f dismissed_comment='{comment}'
```

### 7. Final report

At end, print:

- fixed alerts
- dismissed alerts (with reasons)
- deferred/skipped alerts
- changed files (if any)
- suggested verification commands (language-agnostic; do not assume one toolchain)

If edits were made, remind user to run project-specific checks before commit.

## Rules

- **One alert at a time.** Never batch-dismiss or batch-fix without per-alert review.
- **Approval before mutation.** Never edit code or dismiss alerts without explicit user approval.
- **Evidence-first decisions.** Every fix/dismiss recommendation must cite concrete evidence (path + line + context).
- **No fabricated validation.** Never claim a fix is verified unless commands were actually run.
- **No automatic commits or pushes.** Leave VCS integration decisions to the user unless explicitly requested.
- **Prefer minimal patches.** Keep fixes narrowly scoped to the flagged risk unless user requests broader refactors.
- **Respect unresolved uncertainty.** If confidence is low, defer and document what information is needed next.

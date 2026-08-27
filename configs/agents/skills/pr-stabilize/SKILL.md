---
name: pr-stabilize
description: Stabilize a pull request or stacked PRs by repeatedly waiting for CI and automated review, validating failures and comments, applying only justified in-scope fixes, maintaining stack ancestry, and looping until required CI is green and no valid blockers remain. Autonomous — mutates branches and GitHub state without intermediate approval.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(jq:*), Bash(tone-clone:*), Bash(bun:*), Bash(python3:*), Bash(sleep:*), Bash(date:*), Bash(mktemp:*), Read(*), Write(*), Edit(*)
---

## User overrides

Follow the [shared user override contract](../_shared/user-overrides.md). This skill's gates describe the default workflow, but a direct, explicit user instruction may change or skip them within the scope the user authorizes. This section takes precedence over conflicting gate or approval language elsewhere in this skill.

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` or `gh` invocation.

## Purpose

Drive one pull request or a stack of pull requests to a stable review-ready state without requiring the user to supervise the loop. Wait for current CI and automated review workflows, inspect their real outputs, validate every failure and review comment against the exact branch that owns it, apply only concrete in-scope fixes, maintain stacked branches from base to tip, push safely, and repeat until all required CI succeeds and no unresolved current review thread contains a valid blocker.

The invocation authorizes this skill to edit files, run validation, commit, rebase stack descendants, force-push with lease, rerun transiently failed jobs, reply to review threads, and resolve threads. Do not pause for confirmation unless a required action is destructive beyond the named PR branches, branch ownership is ambiguous, credentials are missing, or the correct fix requires a product decision that cannot be established from repository evidence.

## Workflow

### 1. Establish scope

1. Confirm the current directory is a Git worktree and record:
   - repository owner/name
   - current branch and worktree root
   - clean or dirty status
   - default branch
   - current PR, when one exists
2. Accept explicit PR URLs/numbers when supplied. Otherwise detect the PR for the current branch.
3. Discover a stack by following PR base/head relationships in both directions. Order it base-to-tip.
4. Verify every stack branch is local, tracks the expected remote, and belongs to the same repository.
5. Stay in the current worktree. Switch branches inside it as needed; never create a separate checkout merely to process the stack.
6. Never commit, rebase, merge, or push directly to `truth`, `master`, `main`, or another protected/default branch.
7. Stop if unrelated local changes would be overwritten. If local changes are clearly from the active stabilization work, preserve and finish them.

### 2. Capture current truth

Before diagnosing the PRs:

1. Fetch the latest default branch and stack refs.
2. Record each PR's current head SHA, base SHA, title, URL, merge state, and required checks.
3. Inspect recent default-branch CI runs and their failed jobs.
4. Treat a failure as pre-existing only when equivalent code and the same failing behavior are present on the current default branch. Do not infer this from an old run or from a vaguely similar annotation.
5. Record known default-branch failures with evidence so they can be recognized throughout the loop.

### 3. Wait for the current workflow wave

For every PR head SHA:

1. Find CI, automated code-review, CodeQL, and required repository workflows associated with that exact SHA.
2. Ignore runs for superseded SHAs.
3. Poll every 20–60 seconds with bounded commands. Print concise progress when the state changes or after several minutes.
4. Follow reruns under the same run ID and newly created runs after force-pushes.
5. Wait until all relevant jobs are terminal before deciding the wave's result.
6. A cancelled or missing required run is not success. Determine whether it was superseded, concurrency-cancelled, manually cancelled, or never triggered.
7. Do not stop merely because one job failed while sibling jobs are still producing evidence.

### 4. Diagnose CI failures

For each failed or cancelled required job:

1. Read job and failed-step logs, not only annotations or the run summary.
2. Classify it as one of:
   - PR-introduced correctness failure
   - PR-introduced workflow/runner compatibility failure
   - current default-branch failure
   - transient infrastructure/network/provider failure
   - expected cancellation from a newer run
   - unknown
3. Reproduce the narrowest relevant command locally when practical.
4. Search the changed code, nearby contracts, tests, and default branch before proposing a fix.
5. Retry failed jobs only when logs establish a transient cause such as DNS, codeload, provider download, registry timeout, or runner interruption. Retry once, then diagnose recurrence instead of looping blindly.
6. Never rerun a test, lint, type, build, or contract failure as a substitute for fixing it.
7. Never weaken or delete a valid test, add a skip, or suppress an error merely to make CI green.
8. If a default-branch failure must be tolerated for this PR, use the narrowest explicit mechanism, document the exact owning failure, and keep the underlying command visible. Do not classify a newly introduced failure as upstream.

### 5. Fetch and validate review feedback

Use one paginated GraphQL collection per PR to fetch:

- review threads and all replies
- review summaries
- issue-level comments

Then:

1. Skip resolved and outdated threads.
2. Give human reviewer comments priority over automation.
3. Validate every actionable comment against the exact PR branch where it was posted and against that PR's diff from its base.
4. Address a comment only when all are true:
   - the claim is factually correct
   - the issue is introduced or owned by that PR
   - the change is within that PR's scope
   - the issue is material enough to change
5. Reject or leave unchanged comments that are speculative, duplicate, stylistic without repository backing, based on stale code, owned by another stack PR, already fixed downstream, or unrelated to the PR.
6. Do not let severity labels from bots determine validity.
7. Before replying, use `tone-clone` to sample the user's authentic GitHub review/comment style when useful. Keep replies concise, direct, technical, and non-celebratory.
8. Never write phrases such as "good catch", "great point", "thanks for catching this", or other praise directed at automation.

### 6. Place fixes on the owning branch

1. Map each valid issue to the earliest PR in the stack whose diff introduces or owns it.
2. Switch to that branch and inspect the current file before editing.
3. Keep edits minimal and preserve repository conventions.
4. Load and obey repository instructions and any task-relevant skills before changing code.
5. Add or update tests only when they prove changed behavior. Follow the repository requirement to demonstrate a new test fails for the intended reason before trusting it when practical.
6. Run the smallest validation that proves the fix, plus formatting or contract checks required by repository guidance.
7. Commit with the repository's commit conventions. Do not invent issue references.
8. Reply to the specific review thread with what changed and why. Resolve only threads that were fixed or deliberately disputed with evidence.

### 7. Maintain the stack

After changing any non-tip branch:

1. Record old branch tips before rebasing.
2. Rebase each descendant onto its newly rewritten parent, proceeding base-to-tip.
3. Resolve conflicts by preserving the parent fix and the descendant's owned delta. Never use blanket ours/theirs without inspecting the resulting workflow or code.
4. After each conflict resolution, verify load-bearing lines from both sides still exist.
5. Push rewritten branches only with `--force-with-lease`.
6. Verify:
   - default branch is ancestor of the first PR
   - each PR branch is ancestor of the next
   - PR base/head relationships remain correct
   - no unmerged paths exist
   - `git diff --check` passes across the assembled stack
   - the worktree is clean

### 8. Repeat until stable

After every push or rerun:

1. Return to Step 3 and wait for the new head-SHA workflow wave.
2. After automated review workflows finish, fetch review threads again; comments may arrive after CI finishes.
3. Apply newly valid feedback through Steps 5–7.
4. Continue until all completion conditions hold simultaneously:
   - required CI/status checks succeed on every current PR head
   - no relevant workflow is still pending
   - no unresolved, non-outdated human or automated review thread is a valid blocker
   - stack ancestry and PR base/head relationships are intact
   - worktree is clean
5. Require at least one complete post-fix workflow/review wave with no new valid blocker before declaring success.

### 9. Report completion

Report:

- PR numbers, URLs, branches, and final head SHAs
- successful required CI run IDs for each PR
- fixes made, grouped by owning PR
- review comments fixed, disputed, skipped as stale, or rejected as out of scope
- any explicitly tolerated default-branch failures and the evidence establishing them
- validation commands run
- final stack ancestry and worktree status

## Rules

- Operate autonomously after invocation; do not ask for routine approvals.
- Never mutate the default/protected branch.
- Never leave the current worktree context.
- Never force-push without lease.
- Never claim a run passed until GitHub reports its terminal successful conclusion.
- Never claim review is clear until automated review workflows finish and threads are fetched again.
- Never treat an outdated, resolved, or superseded comment as current work.
- Never address feedback on the wrong PR merely because the tip contains the code.
- Never make unrelated cleanup changes while stabilizing CI or review.
- Never weaken correctness checks to hide a PR-owned failure.
- Never repeatedly rerun deterministic failures.
- Never reply with bot praise or filler.
- Prefer factual disagreement over unnecessary code changes.
- If stack ownership or the correct product behavior is genuinely ambiguous, stop and ask one concise blocking question with the gathered evidence.

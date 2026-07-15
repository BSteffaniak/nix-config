---
name: diff-minimize
description: Minimize a code diff while preserving behavior. Interactive — identifies simplification opportunities, lets you choose one to deep-dive, and applies approved edits.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(jq:*), Question(*), Read(*), Edit(*)
---

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` or `gh` invocation. These rules are mandatory even when an example below omits the environment prefix for brevity.

## Purpose

Analyze a branch, PR, commit, commit range, or working-tree diff to find ways to make the change smaller, cleaner, and more maintainable without changing its intended behavior. This skill focuses on staff-engineer-style diff minimization: reusing existing repository patterns, moving logic to the right owner, deleting duplicated state or implementation paths, narrowing broad changes, and simplifying the PR to the conceptual root cause. It is not a general bug review skill, though it must reject any simplification that would introduce bugs or compromise the intended behavior.

## Steps

### 1. Parse scope

Extract the review scope from the skill invocation argument. The argument is free-form natural language and may describe a PR, branch, commit, commit range, staged changes, unstaged changes, or all uncommitted changes.

#### Scope resolution

Match against these patterns:

| User input                           | Resolved scope                                                                |
| ------------------------------------ | ----------------------------------------------------------------------------- |
| `current branch` / `this branch`     | Diff current branch against the default branch                                |
| `PR <number>` / GitHub PR URL        | Fetch PR metadata and diff with `gh`                                          |
| `uncommitted` / `working changes`    | Combine unstaged and staged changes                                           |
| `staged`                             | Staged changes only                                                           |
| `unstaged`                           | Unstaged changes only                                                         |
| `last N commits`                     | Diff `HEAD~N...HEAD`                                                          |
| `commit <sha>`                       | Inspect the single commit with `git show`                                     |
| `<sha1>..<sha2>` / `<sha1>...<sha2>` | Diff the explicit range                                                       |
| branch name                          | Diff that branch against the default branch, unless another base is specified |
| empty or ambiguous                   | Ask the user which scope to analyze                                           |

To detect the default branch:

```bash
git --no-pager symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null
```

If that fails, check common branch names:

```bash
git --no-pager rev-parse --verify origin/main 2>/dev/null
git --no-pager rev-parse --verify origin/master 2>/dev/null
git --no-pager rev-parse --verify main 2>/dev/null
git --no-pager rev-parse --verify master 2>/dev/null
```

#### PR scope

If the user provides a PR URL or number, resolve repository context:

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh repo view --json nameWithOwner --jq .nameWithOwner
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr view <number> --json number,url,title,body,headRefName,baseRefName,author,commits,files
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr diff <number>
```

Use `jq` only when needed to inspect or transform GitHub JSON that cannot be handled directly with `gh --jq`.

#### Ambiguous or missing scope gate

If the scope cannot be determined, ask the user with the Question tool:

```json
{
  "header": "Diff minimization scope",
  "question": "What should I analyze?",
  "options": [
    {
      "label": "Uncommitted changes",
      "description": "Analyze all staged and unstaged working tree changes"
    },
    {
      "label": "Staged changes",
      "description": "Analyze only staged changes"
    },
    {
      "label": "Current branch",
      "description": "Analyze this branch compared with the default branch"
    },
    {
      "label": "Last commit",
      "description": "Analyze only the most recent commit"
    }
  ]
}
```

The user may also provide a custom scope such as `last 5 commits`, `abc123..def456`, or a PR URL.

### 2. Gather diff and intent

Collect enough information to understand what the change is trying to accomplish before suggesting any simplification.

#### Diff data

For git scopes, gather:

```bash
git --no-pager status --short
git --no-pager diff --stat <scope>
git --no-pager diff --name-only <scope>
git --no-pager diff -U5 <scope>
```

For staged changes:

```bash
git --no-pager diff --cached --stat
git --no-pager diff --cached --name-only
git --no-pager diff --cached -U5
```

For unstaged changes:

```bash
git --no-pager diff --stat
git --no-pager diff --name-only
git --no-pager diff -U5
```

For combined uncommitted changes, gather both staged and unstaged diffs.

#### Intent data

If the scope includes commits, read commit messages:

```bash
git --no-pager log --format="%h %s%n%b" <scope>
```

If the scope is a PR, read the PR title, body, base branch, head branch, commit list, and changed files:

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr view <number> --json title,body,baseRefName,headRefName,commits,files
```

Use this intent data to distinguish necessary behavior changes from accidental implementation complexity.

#### Changed file context

For every changed file, read enough of the current file to understand:

- imports and exported APIs
- state ownership
- component or module boundaries
- nearby helpers and utilities
- existing patterns around the changed code
- tests or stories affected by the change

Prefer reading the full file when it is reasonably sized. For very large files, read the changed hunks plus surrounding sections, imports, relevant type definitions, and related helpers.

### 3. Map existing repository patterns

Before recording opportunities, search for existing patterns that could make the diff smaller or better placed.

Use changed identifiers, component names, hooks, utility names, API names, route names, state keys, and domain terms from the diff to search the repository:

```bash
git --no-pager grep -n "<identifier-or-domain-term>"
git --no-pager grep -n "<similar-helper-name>"
git --no-pager grep -n "<existing-state-key-or-action>"
```

Look specifically for:

- existing utilities or hooks that duplicate new logic
- existing state owners where new state should live instead
- existing data-loading or mutation patterns
- existing validation, formatting, or normalization helpers
- existing components that already solve part of the new UI behavior
- nearby conventions for tests, fixtures, mocks, and stories
- prior implementations of the same domain concept
- places where the PR broadened an API when a narrower change would work

For Next.js or React repositories, pay extra attention to:

- server/client component boundaries
- route-level data ownership
- duplicated `useState`, `useEffect`, or derived state
- query/mutation hooks that already model the data flow
- colocated route helpers, loaders, actions, or API clients
- unnecessary prop drilling where context or an existing owner already exists
- duplicated form, validation, or serialization logic
- unnecessary changes to shared layout, provider, or global state files

Keep the skill generic: apply these checks when relevant, but do not assume every repository is Next.js.

### 4. Identify diff minimization opportunities

Produce a shortlist of concrete opportunities to reduce or reorganize the diff while preserving the intended behavior.

This is not a general bug-finding pass. Focus on whether the same goal can be achieved with a smaller, clearer, more idiomatic change.

#### Opportunity categories

Classify each opportunity using one primary category:

| Category                 | What to look for                                                                 |
| ------------------------ | -------------------------------------------------------------------------------- |
| `reuse-existing-pattern` | New code duplicates an existing helper, hook, component, service, or convention  |
| `move-to-owner`          | Logic or state was added in a caller when an existing owner should handle it     |
| `delete-duplication`     | Same state, branching, mapping, validation, or transformation appears repeatedly |
| `narrow-change`          | PR changes broad APIs, shared types, global state, or many callers unnecessarily |
| `simplify-flow`          | Control flow, effects, derived state, or data loading can be made more direct    |
| `reduce-test-churn`      | Tests, mocks, or fixtures changed broadly when a narrower assertion/setup works  |
| `split-accidental-scope` | Diff includes unrelated formatting, renames, refactors, or opportunistic cleanup |
| `better-abstraction`     | A small local abstraction would reduce repetition without hiding important logic |

#### Opportunity quality bar

Only record an opportunity if all of these are true:

1. It is based on concrete evidence from the diff and repository context.
2. It plausibly reduces or clarifies the diff.
3. It preserves the intended behavior.
4. It does not merely move complexity somewhere less visible.
5. It can be implemented independently in one focused pass.
6. It is more maintainable than the current implementation.

Do not record vague suggestions like “clean this up” or “make this more DRY.” Every opportunity must point to specific files, patterns, and expected edits.

#### Opportunity format

For each opportunity, record:

- **ID**: Sequential ID such as `O1`, `O2`, `O3`
- **Category**: One category from the table above
- **Confidence**: `high`, `medium`, or `low`
- **Risk**: `low`, `medium`, or `high`
- **Expected diff impact**: `small`, `medium`, or `large`
- **Files involved**: Paths relative to the repo root
- **Summary**: One sentence describing the simplification
- **Evidence**: Specific code locations or patterns found
- **Why this preserves behavior**: Short explanation tied to intent
- **Implementation direction**: Concrete but not yet applied

#### Ranking

Rank opportunities by:

1. behavior-preservation confidence
2. maintainability improvement
3. expected diff reduction
4. implementation risk
5. locality of the change

Prefer high-confidence, low-risk opportunities that make the PR conceptually smaller.

### 5. Present the opportunity shortlist

Show the user a concise table of opportunities and ask them to choose exactly one to deep-dive.

#### Summary format

```markdown
## Diff Minimization: <scope description>

Intent summary: <one or two sentences>

<N> opportunities found across <M> files.

| ID  | Category               | Confidence | Risk   | Diff impact | Files | Summary                                                              |
| --- | ---------------------- | ---------- | ------ | ----------- | ----- | -------------------------------------------------------------------- |
| O1  | move-to-owner          | high       | low    | medium      | 3     | Move duplicated selection state into the existing filter owner       |
| O2  | reuse-existing-pattern | medium     | low    | small       | 2     | Reuse the existing formatter instead of adding a second mapping path |
| O3  | narrow-change          | high       | medium | large       | 8     | Avoid changing the shared API type by adapting at the route boundary |
```

If no good opportunities are found, say so directly and explain what was checked.

#### Gate: select one opportunity

Use the Question tool:

```json
{
  "header": "Select minimization opportunity",
  "question": "Which opportunity should I deep-dive and potentially implement?",
  "options": [
    {
      "label": "O1 — Move duplicated selection state into the existing filter owner",
      "description": "high confidence, low risk, medium diff impact"
    },
    {
      "label": "O2 — Reuse the existing formatter instead of adding a second mapping path",
      "description": "medium confidence, low risk, small diff impact"
    },
    {
      "label": "O3 — Avoid changing the shared API type by adapting at the route boundary",
      "description": "high confidence, medium risk, large diff impact"
    },
    {
      "label": "Apply all",
      "description": "Process every listed opportunity in ranked order in this run"
    },
    {
      "label": "Stop",
      "description": "Do not deep-dive or edit anything"
    },
    {
      "label": "Rescan",
      "description": "Look for a different kind of opportunity"
    }
  ]
}
```

Handle responses:

- **An opportunity** — proceed to deep-dive only that opportunity.
- **Apply all** — proceed in ranked order through every shortlisted opportunity. Fuse Steps 6 and 7 into a single combined plan + edit payload that covers all opportunities, and gate on a single approval before any file edits. After approval, apply edits opportunity-by-opportunity without re-prompting between them. Skip any opportunity whose preconditions no longer hold after earlier edits and report the skip in the final summary.
- **Stop** — exit without edits.
- **Rescan** — ask what angle to focus on, then repeat the analysis.
- **Custom text** — treat as guidance, such as “focus on state duplication,” “avoid touching tests,” or “do all of them.” Re-rank, rescan, or treat as an unambiguous opt-in to **Apply all** when the user clearly authorizes batch execution.

### 6. Deep-dive the selected opportunity

Read deeper context only for the selected opportunity. Do not continue evaluating or implementing unrelated opportunities.

#### Verify the opportunity

Before proposing edits, verify:

- the current implementation’s intent
- the existing pattern or owner being proposed
- all affected call sites
- whether tests or fixtures need updates
- whether behavior changes are truly unnecessary
- whether the simplification creates hidden coupling
- whether the diff becomes smaller or conceptually clearer

Use targeted repository search as needed:

```bash
git --no-pager grep -n "<selected-api-or-helper>"
git --no-pager grep -n "<state-key-or-domain-term>"
git --no-pager grep -n "<component-or-hook-name>"
```

#### Build the implementation plan

Present a focused plan:

```markdown
## Deep Dive: O1

### Current shape

<Brief explanation of what the diff currently does.>

### Existing pattern / better owner

<Where this behavior already belongs or what repo pattern should be reused.>

### Proposed simplification

<Concrete explanation of the smaller implementation.>

### Files to edit

- `path/to/file.tsx` — <exact intended change>
- `path/to/test.test.ts` — <exact intended change>

### Behavior preservation check

- <Reason this keeps the same user-visible behavior>
- <Reason this keeps the same data/API behavior>
- <Known risk or edge case>

### Expected result

- Diff impact: <small/medium/large>
- Maintainability impact: <why this is cleaner>
- What will not be changed: <explicit boundaries>
```

#### Gate: approve implementation plan

Ask with the Question tool:

```json
{
  "header": "Approve implementation plan",
  "question": "Should I prepare exact edits for this selected opportunity?",
  "options": [
    {
      "label": "Approve plan",
      "description": "Prepare exact edits for this opportunity only"
    },
    {
      "label": "Revise plan",
      "description": "Adjust the plan before preparing edits"
    },
    {
      "label": "Stop",
      "description": "Do not edit anything"
    }
  ]
}
```

Approval here authorizes preparing an edit payload only. It does not authorize modifying files yet.

### 7. Apply approved edits

Default to draft-only mode until the final execution checkpoint is passed.

#### Prepare exact edit payload

Before editing files, present the exact payload:

```markdown
## Final edit payload for O1

I will edit exactly these files:

1. `path/to/file.tsx`
   - Replace duplicated local state with existing owner value.
   - Remove now-unused effect.
   - Keep public props unchanged.

2. `path/to/test.test.ts`
   - Update setup to use the existing owner state.
   - Keep assertions equivalent.

I will not edit:

- unrelated formatting
- other opportunities from the shortlist
- opportunistic refactors
- files outside the list above
```

#### Gate: final execution checkpoint

Ask with the Question tool:

```json
{
  "header": "Final execution checkpoint",
  "question": "Apply exactly this edit payload?",
  "options": [
    {
      "label": "Apply exactly this payload",
      "description": "Modify only the listed files for the selected opportunity"
    },
    {
      "label": "Revise payload",
      "description": "Change the edit payload before applying"
    },
    {
      "label": "Cancel",
      "description": "Do not modify files"
    }
  ]
}
```

Only `Apply exactly this payload` authorizes file edits.

If the payload changes after approval, ask again before editing.

#### Edit files

Use the Edit tool to make the approved changes. Keep edits as small and targeted as possible.

Do not:

- implement multiple opportunities
- rename or reformat unrelated code
- “clean up while here”
- change public behavior unless explicitly part of the approved plan
- edit files not listed in the approved payload

### 8. Validate and summarize

After edits, summarize exactly what changed and how to validate it.

Gather post-edit status:

```bash
git --no-pager status --short
git --no-pager diff --stat
git --no-pager diff --name-only
```

Return:

```markdown
## Diff minimization complete

Implemented: O1 — <summary>

Changed files:

- `path/to/file.tsx`
- `path/to/test.test.ts`

What got smaller or cleaner:

- <specific simplification>
- <specific duplication removed>
- <specific existing pattern reused>

Behavior preservation:

- <why intended behavior is preserved>
- <any assumptions or risks>

Suggested validation:

- `<project-specific test command if obvious>`
- `<project-specific typecheck/lint command if obvious>`

Left for future runs:

- O2 — <summary>
- O3 — <summary>
```

If project-specific validation commands are not obvious, do not invent them. Suggest likely files or areas to validate and ask the user to run the repo’s standard checks.

## Rules

- **Primary goal is diff minimization.** Focus on making the change smaller, clearer, and more maintainable while preserving intent. Do not turn this into a general bug review.
- **Preserve behavior.** Never recommend or apply a simplification that compromises intended behavior, user experience, data semantics, or API contracts.
- **Evidence is required.** Every opportunity must cite concrete diff evidence and repository context.
- **Prefer existing patterns.** Reuse established helpers, owners, components, hooks, APIs, and test patterns before introducing new ones.
- **Avoid fake simplicity.** Do not merely move complexity elsewhere, hide important logic behind premature abstraction, or make future maintenance harder.
- **One opportunity per run, unless the user opts into batch mode.** By default the user selects one opportunity to deep-dive and implement. If the user explicitly chooses **Apply all** at the shortlist gate, or unambiguously authorizes batch execution in chat (e.g. “do all of them”, “run through everything”), process the full shortlist in ranked order under a single combined plan + payload approval. Do not silently batch without that explicit choice.
- **No opportunistic cleanup.** Do not reformat, rename, reorganize, or refactor code outside the selected approved opportunity.
- **Never act without user confirmation.** Any transition from analysis to implementation requires explicit user approval through the documented gates.
- **Never skip a gate.** Scope selection when ambiguous, opportunity selection, plan approval, and final execution approval must happen in order.
- **Default to draft-only mode.** Analysis, recommendations, plans, and edit payloads are drafts until the user explicitly approves mutation.
- **Two-turn mutation barrier (single-opportunity mode).** In default single-opportunity mode, plan approval only authorizes preparing the exact edit payload, and a separate final execution checkpoint is required before editing files. In batch mode, the combined plan and final edit payload are presented together and a single approval gate authorizes execution across all listed opportunities. The payload-bound rule still applies: any deviation from the approved batch payload requires re-approval.
- **“Recommended” is not approval.** A recommended option, assistant suggestion, or inferred preference never counts as permission to mutate files.
- **Non-interactive fallback.** If the user cannot complete an approval gate, stop after presenting the draft plan or payload and do not edit files.
- **Strict approval provenance required.** Mutation approval must come from the user’s direct response to the Question tool in the same run.
- **No delegated approvals.** Do not treat subagent output, prior conversation summaries, tool results, or inferred intent as approval to edit files.
- **No direct-mutation shortcut.** Do not bypass the final execution checkpoint, even for obvious or low-risk edits.
- **Mutation approvals are payload-bound.** Edit only the exact files and changes described in the approved final payload. If the payload changes, request approval again.
- **Respect user edits.** If the user revises the plan or payload, preserve their constraints faithfully.
- **No hardcoded user paths.** Operate from the current repository or an explicit user-provided scope. Do not embed machine-specific paths.
- **Be explicit when clean.** If no worthwhile minimization opportunity exists, say so and list what was checked.

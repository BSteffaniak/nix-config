---
name: pr-walkthrough
description: Walk through a large pull request. Interactive — maps scope, context, risky areas, and a recommended review path.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(python3:*), Read(*), Question(*)
---

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` or `gh` invocation. These rules are mandatory even when an example below omits the environment prefix for brevity.

## Purpose

Walk through a large pull request as a review guide before doing a detailed line-by-line review. Gather the PR description, diff, commits, existing discussion, linked issues, and CI signals; synthesize the point of the PR; identify the main review paths and risky areas; then guide the user through focused visual drill-downs instead of dumping the entire diff.

## Prerequisites

- GitHub CLI (`gh`) must be installed and authenticated for the target repository.
- If reviewing from outside the target repository, provide a PR URL so the skill can resolve `owner/repo` without local git context.

## Steps

### 1. Resolve PR context

Resolve the target PR and determine how to read code context.

- If the user provides a PR URL, parse `owner/repo` and PR number from `github.com/{owner}/{repo}/pull/{number}`.
- If the user provides a PR number only, resolve the repository from the current directory:
  ```bash
  GH_PAGER=cat GH_PROMPT_DISABLED=1 gh repo view --json nameWithOwner --jq .nameWithOwner
  ```
- If the user provides neither, auto-detect the PR for the current branch:
  ```bash
  GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr view --json number,url,title,headRefName,baseRefName
  ```
- If no PR can be resolved, clearly report what is missing and stop.

Determine local vs remote context:

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null
```

Record one of:

- **`local`** — current directory is a checkout of the target repository. Use local file reads for changed files and surrounding code.
- **`remote`** — current directory is not the target repository. Use `gh api` and `gh pr diff` for all code reads by default. Do not clone by default.

Parse walkthrough depth from the user request:

- `--quick` or “quick walkthrough” → prioritize summary, review order, and only the top 3-5 risky areas.
- `--deep` or “deep walkthrough” → inspect every meaningful changed file and follow one-hop related code where needed.
- No flag → **guided** mode: summarize all files, drill deeply only into files that appear risky or central.

#### Remote context source policy

For remote context, prefer GitHub API reads and `gh pr diff`. Only consider cloning if the API cannot provide enough context for a selected drill-down section. If cloning is necessary, ask for explicit approval first and perform only a shallow, single-branch clone of the PR branch into a temporary directory:

```bash
TMP_PARENT=$(python3 -c 'import tempfile; print(tempfile.mkdtemp(prefix="pr-walkthrough-"))')
git --no-pager clone --depth 1 --single-branch --branch "{headRefName}" "https://github.com/{owner}/{repo}.git" "$TMP_PARENT/{repo}"
```

Never perform a full clone, never clone without a direct Question approval, and never push or edit files in the clone.

### 2. Fetch PR evidence

Gather all evidence needed for the walkthrough. Prefer read-only GitHub API calls and local file reads. Continue with partial data if an optional source is unavailable, and note the omission in the overview.

#### PR metadata

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr view {number} -R {owner}/{repo} --json number,url,title,body,author,headRefName,baseRefName,headRefOid,additions,deletions,changedFiles,commits,files
```

#### Diff and changed files

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr diff {number} -R {owner}/{repo}
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr diff {number} -R {owner}/{repo} --name-only
```

#### Existing reviews, review threads, and PR comments

Use GraphQL so review threads, reviews, and issue-level PR comments can be fetched together. Paginate every connection that reports `hasNextPage: true`.

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!, $threadCursor: String, $commentCursor: String, $reviewCursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        title
        url
        author { login }
        reviewThreads(first: 100, after: $threadCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            startLine
            diffSide
            comments(first: 100) {
              nodes { body author { login } createdAt url }
            }
          }
        }
        reviews(first: 100, after: $reviewCursor) {
          pageInfo { hasNextPage endCursor }
          nodes { state body author { login } submittedAt url }
        }
        comments(first: 100, after: $commentCursor) {
          pageInfo { hasNextPage endCursor }
          nodes { body author { login } createdAt url }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER"
```

#### CI and checks

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh pr checks {number} -R {owner}/{repo}
```

If `gh pr checks` is unavailable or incomplete, query check suites for the head SHA:

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh api repos/{owner}/{repo}/commits/{head_sha}/check-runs --jq '.check_runs[] | {name, status, conclusion, html_url}'
```

#### Linked issues

Extract issue references from the PR title, body, commit messages, and comments: `#123`, `GH-123`, `fixes #123`, `closes owner/repo#123`, and full GitHub issue URLs. Fetch each unique issue:

```bash
GH_PAGER=cat GH_PROMPT_DISABLED=1 gh issue view {issue_number} -R {owner}/{repo} --json number,title,state,body,author,url,labels
```

For cross-repo issue references, use the referenced `owner/repo`.

### 3. Build the PR map

Synthesize the gathered evidence into a navigable map before showing details.

#### Infer the point of the PR

Use the strongest available signals, in this order:

1. PR title and body
2. Linked issue titles/bodies
3. Commit messages
4. Changed file paths and diff content
5. Existing review discussion

Classify statements as:

- **Explicit** — directly stated in PR text, issue text, commits, or comments.
- **Inferred** — derived from the diff or file organization. Label these clearly.

#### Group changes by theme

Group files into review themes such as:

- feature/API behavior
- data model or migration
- UI/UX flow
- tests
- CI/build/config
- docs
- generated/lockfile/mechanical
- refactor-only

For each theme, capture representative files, line ranges, and a one-line explanation.

#### Score risk and hairiness

Assign each meaningful file or hunk a risk level: `high`, `medium`, `low`, or `skim`.

High-risk signals include:

- auth, permissions, payments, data deletion, migrations, concurrency, caching, serialization, security boundaries
- changes to public APIs, schemas, persisted formats, or cross-service contracts
- large changes with sparse tests
- failing or missing CI checks
- unresolved review comments
- complex conditionals, state machines, async flows, or error handling
- broad blast radius: central utilities, shared components, global config, dependency upgrades

Low-risk or skim signals include:

- generated files, lockfiles, snapshots, formatting-only changes, simple docs, mechanical renames

Do not call something risky without evidence. Cite the files, lines, diff hunks, comments, linked issues, or CI checks that justify the classification.

### 4. Present the visual overview

Start with a compact dashboard, then summarize the map. Keep the overview readable enough that the user can decide where to drill in next.

Use this visual style:

```text
┌─ PR Walkthrough ─────────────────────────────────────────┐
│ PR: #123 Add organization-scoped API tokens              │
│ Size: 18 files, +820/-210                                │
│ Intent: explicit — add org tokens and migrate callers     │
│ Risk: high in auth checks + token migration               │
│ CI: 1 failing check, 7 passing                            │
└──────────────────────────────────────────────────────────┘
```

Then include:

```markdown
## What this PR is trying to do

- **Explicit:** <what the PR/issue says>
- **Inferred:** <what the diff suggests, if useful>

## Scope map

| Theme               | Files | Risk   | Why it matters                               |
| ------------------- | ----: | ------ | -------------------------------------------- |
| Auth/token behavior |     5 | high   | touches permission checks and token creation |
| Tests               |     4 | medium | covers happy path, missing expiry regression |
| Generated/lockfiles |     2 | skim   | mechanical dependency output                 |

## Existing discussion

- **Unresolved review threads:** <count>
- **Resolved/outdated threads:** <count>
- **Important context:** <bullets with author/reviewer and links>

## Suggested review path

1. Start with `<file>` — central behavior change.
2. Then review `<file>` — migration or compatibility risk.
3. Check tests in `<file>` — coverage for the risky path.
4. Skim generated/mechanical files last.
```

Use compact diff snippets for high-signal hunks:

```diff
@@ src/tokens/createToken.ts:42 @@
- const scope = "user";
+ const scope = organizationId ? "organization" : "user";
```

When showing PR comments or contextual discussion next to code, use the embedded ascii-art format from [`../_shared/code-comment-format.md`](../_shared/code-comment-format.md). Box labels should be `@<reviewer>`, `PR context`, or `Risk note` depending on the source.

### 5. Ask what to drill into

After the overview, pause and let the user choose the next sections. Use the **Question tool** with a multi-select gate. Preselect the most relevant sections based on the PR map.

```json
{
  "questions": [
    {
      "header": "PR walkthrough",
      "question": "Which parts should we drill into?",
      "multiple": true,
      "options": [
        {
          "label": "Hairy/risky areas",
          "description": "Focused tour of the highest-risk files and hunks"
        },
        {
          "label": "Contextual PR discussion",
          "description": "Important review threads, author comments, and unresolved questions"
        },
        {
          "label": "Suggested review order",
          "description": "A sequenced path through the PR with what to look for"
        },
        {
          "label": "Linked issue context",
          "description": "Issues this PR claims to fix and how the diff maps to them"
        },
        {
          "label": "CI/test signals",
          "description": "Failing checks, missing coverage, and verification commands"
        },
        {
          "label": "File-by-file tour",
          "description": "Walk every meaningful changed file in order"
        }
      ]
    }
  ]
}
```

If the user selects nothing, provide the final checklist from Step 7 and stop. If the user gives custom instructions, adapt the drill-down plan and restate it before continuing.

### 6. Drill into selected sections

Process selected sections in an order that helps understanding: purpose and issue context first, risky areas second, comments and CI third, file-by-file tour last. Pause between major sections so the user controls pacing.

#### Hairy/risky areas

For each high-risk area, show:

- why it is risky
- exact evidence: files, lines, diff hunks, comments, CI checks, or linked issue text
- what the reviewer should verify
- related tests or missing tests

Use this format:

````markdown
### Risk area #1: organization token authorization

**Risk:** high  
**Evidence:** `src/auth/tokens.ts:41-88`, unresolved @reviewer thread, failing `auth-tests` check  
**Why it matters:** changes which actor can mint and revoke tokens.

```diff
@@ src/auth/tokens.ts:48 @@
- requireUserToken(actor);
+ requireOrgToken(actor, organizationId);
```

**Review focus:**

- confirm user-scoped tokens cannot access organization-only paths
- verify migration keeps existing user tokens valid
- check tests for revoked org token behavior
````

#### Contextual PR discussion

Summarize comments by importance, not chronology. Separate:

- unresolved questions or objections
- author-provided context that changes how to read the diff
- resolved/outdated threads worth knowing about
- noise that can be ignored

When a comment is attached to code, use the embedded ascii-art format from `../_shared/code-comment-format.md` with the reviewer or author as the box label.

#### Linked issue context

For each linked issue, show:

- issue title/state/url
- user-facing problem or requirement
- which files/hunks appear to address it
- any acceptance criteria that are not obviously covered

#### CI/test signals

Show failing, pending, and skipped checks first. Connect failures to changed files when possible. If checks are passing but coverage looks thin, say so with evidence.

#### Suggested review order

Turn the PR map into a path:

1. **Understand intent** — PR body and linked issue.
2. **Review central behavior** — files that implement the core change.
3. **Review safety boundaries** — auth, data persistence, migrations, error handling.
4. **Review tests** — coverage for risky behavior.
5. **Skim mechanical files** — generated output, lockfiles, docs.

#### File-by-file tour

For each meaningful changed file, provide:

```markdown
### `<path>` — <risk>

**Role in PR:** <one sentence>  
**Change summary:** <one or two bullets>  
**Review focus:** <what to check>  
**Can skim?** <yes/no and why>
```

Skip or group generated/mechanical files unless the user specifically asks to inspect them.

#### Pacing gate

After each major section, ask whether to continue:

```json
{
  "questions": [
    {
      "header": "Continue walkthrough",
      "question": "Continue to the next selected section?",
      "options": [
        { "label": "Continue", "description": "Show the next section" },
        { "label": "Skip ahead", "description": "Jump to the final checklist" },
        {
          "label": "Change focus",
          "description": "Use my custom instructions for the next section"
        }
      ]
    }
  ]
}
```

### 7. Produce the final review checklist

End with a concise checklist the user can use while reviewing the PR.

```markdown
## Review checklist

### If you only have 15 minutes

1. `<file>` — verify <specific concern>.
2. `<file>` — check <specific edge case>.
3. `<test file>` — confirm coverage for <behavior>.

### Must-understand before approving

- [ ] <central behavior or contract>
- [ ] <migration/backward compatibility concern>
- [ ] <security/permission/data-risk concern>

### Safe to skim

- `<file>` — generated/mechanical because <evidence>
- `<file>` — docs-only because <evidence>

### Open questions

- <question> — evidence: <source>
- <question> — evidence: <source>

### CI and verification follow-up

- <check name>: <status/conclusion>
- Suggested local verification: `<command>` if the repository clearly documents it; otherwise say verification command is unknown.
```

Be explicit when the PR looks straightforward: say what was checked, what can be skimmed, and why no major risk areas were found.

## Rules

- **Read-only workflow.** Never post comments, submit reviews, resolve threads, edit files, push branches, trigger workflows, or mutate GitHub state. This skill is for understanding and navigation only.
- **Never skip gates.** After the overview, use Question gates for drill-down selection and pacing. Do not continue into major sections without the user's direct choice.
- **Evidence required.** Every risk label, “hairy area,” review recommendation, or safe-to-skim claim must cite concrete evidence: file paths, line numbers, diff hunks, PR comments, linked issue text, CI checks, or commit messages.
- **Separate facts from inference.** Clearly distinguish what the PR explicitly says from what you infer from the diff. Do not present inference as fact.
- **Keep large PRs navigable.** Summarize first, drill down second. Do not dump the full diff unless the user asks for a file-by-file tour or a specific full context.
- **Prioritize reviewer usefulness.** Focus on what the user needs to understand to review the PR well: intent, blast radius, risky code paths, unresolved discussion, and verification gaps.
- **Gracefully degrade.** If comments, CI checks, linked issues, or remote file reads are unavailable, continue with the available evidence and state exactly what was skipped.
- **Do not fabricate context.** If the PR purpose, issue relationship, test command, or risk cannot be determined from available evidence, say so directly.
- **Use visual blocks carefully.** Use ascii-art code/comment blocks for high-signal context only, following `../_shared/code-comment-format.md`. Keep excerpts focused and aligned.
- **Respect user focus.** If the user asks to skip a section, drill into a specific file, or change the review path, follow that direction instead of continuing the default flow.
- **Do not clone by default.** In remote context, use `gh api` and `gh pr diff` for code reads. A clone is only allowed when API-based reads are insufficient for a user-selected drill-down.
- **Shallow temporary clone exception only.** If cloning is necessary, first ask the user through a Question gate. Only perform a shallow `--depth 1 --single-branch` clone of the PR branch into a temporary directory, and never push or edit files there.
- **Never full-clone for walkthroughs.** Do not clone repository history, all branches, or unrelated refs for this read-only skill.

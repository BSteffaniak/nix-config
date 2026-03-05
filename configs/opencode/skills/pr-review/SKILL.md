---
name: pr-review
description: Fetch and address PR review comments. Validates comment accuracy against the codebase, categorizes as actionable or informational, skips resolved threads, and makes code changes.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*)
---

## Purpose

Fetch all review feedback on a pull request, categorize each comment as actionable or non-actionable, validate actionable comments against the actual codebase to catch incorrect or context-blind feedback, skip resolved/outdated threads, present a structured plan with validity assessments, and then make code changes for the comments the user chooses to address.

## Steps

### 1. Identify the PR

- If the user provides a PR number or URL as an argument, use that.
- Otherwise, auto-detect from the current branch:
  ```bash
  gh pr view --json number,url,title,headRefName,baseRefName
  ```
- If no PR is found for the current branch, inform the user and stop.
- Extract `owner` and `repo` from the repo context:
  ```bash
  gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
  ```

### 2. Fetch all review data

Use a **single GraphQL query** via `gh api graphql` to fetch all review threads, reviews, and issue-level comments. Paginate using cursor-based pagination until all data is retrieved.

#### Initial query

```bash
gh api graphql -f query='
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
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                body
                author { login }
                createdAt
                url
              }
            }
          }
        }
        reviews(first: 100, after: $reviewCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            state
            body
            author { login }
            submittedAt
          }
        }
        comments(first: 100, after: $commentCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            body
            author { login }
            createdAt
            url
          }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER"
```

#### Pagination loop

After each query, check `pageInfo.hasNextPage` on each of the three connections (`reviewThreads`, `reviews`, `comments`). If any is `true`, re-run the query passing the `endCursor` value as the corresponding cursor variable (`$threadCursor`, `$reviewCursor`, `$commentCursor`). Merge the `nodes` arrays from each page. Continue until all three connections report `hasNextPage: false`.

For **nested pagination** (comments within a single review thread with 100+ comments): if any thread's `comments.pageInfo.hasNextPage` is `true`, fetch the remaining comments for that specific thread with a targeted query using the thread's `id` and the comment `endCursor`. In practice this is extremely rare.

### 3. Filter and categorize

#### Filter

- **Resolved threads** (`isResolved: true`): Skip entirely. Collect them into a "Skipped" list for the summary.
- **Outdated threads** (`isOutdated: true`): Flag as outdated in the output, but still include if unresolved — the reviewer hasn't dismissed the concern.

#### Categorize

Classify each unresolved review thread and each issue-level comment into one of these categories based on the comment text:

| Category                           | Key           | When to use                                                                                                                                    |
| ---------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Actionable — Code Change**       | `code-change` | The comment requests a specific code modification: fix a bug, rename something, add error handling, change an approach, remove dead code, etc. |
| **Actionable — Question**          | `question`    | The reviewer asks a question that needs a response. May also imply a code change depending on the answer.                                      |
| **Non-actionable — Praise**        | `praise`      | Positive feedback, approval, "LGTM", "nice", "good catch", etc. No action required.                                                            |
| **Non-actionable — Informational** | `info`        | FYI notes, context, references to other code, explanations. No action expected.                                                                |

**Categorization guidelines:**

- Look at the **last comment** in a review thread to determine the current state — an earlier request may have been addressed in a follow-up reply within the same thread.
- If a thread contains back-and-forth discussion and the last message is from the PR author acknowledging the feedback, it is likely already addressed — categorize as `info` unless the reviewer responded after with further requests.
- Comments that say things like "nit:", "optional:", "take it or leave it" are still `code-change` but should be flagged as **low priority** in the output.
- Questions phrased as suggestions ("Should this use X instead?", "What about doing Y?") are `question` — they need the author's judgment.
- Review summaries with `state: APPROVED` and no actionable body text are `praise`.
- Review summaries with `state: CHANGES_REQUESTED` should have their body text categorized like any other comment.
- Review summaries with `state: COMMENTED` and an empty/generic body can be ignored (the substance is in the thread comments).

### 4. Validate actionable comments

Before presenting results, validate every actionable comment (`code-change` and `question`) against the actual codebase. The goal is to catch reviewer comments that are wrong, missing context, or based on stale assumptions.

#### Validation tiers

Dynamically choose the validation depth based on the comment's complexity. Do not over-invest time on obvious comments, but go deep when something smells off.

| Tier         | When to use                                                                                                                                                                                                             | What to do                                                                                                                                                                                                                                                                                                                                     |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Shallow**  | Clear-cut, unambiguous requests: typo fixes, obvious missing imports, straightforward renames, simple formatting issues                                                                                                 | Read the referenced file at the specified line. Confirm the issue the reviewer describes actually exists in the current code. Done.                                                                                                                                                                                                            |
| **Standard** | Most code change requests: add error handling, refactor this block, change an approach, use a different API                                                                                                             | Read the file and understand the surrounding function/block context — imports, the enclosing function, adjacent logic. Verify the reviewer's claim holds given this context. Check if the concern is already handled nearby (e.g., a null check 3 lines above, a try/catch in the caller).                                                     |
| **Deep**     | Complex or suspicious comments: architectural claims, references to project conventions, assertions that something "will break" or "should work differently", or anything that contradicts what you can see in the code | Search the codebase for related patterns, usages, and conventions. If the reviewer says "the rest of the codebase does X", verify that claim. If the comment implies code was changed incorrectly, check `git log`/`git blame` on the relevant lines to understand intent. If the reviewer references a specific file or function, go read it. |

#### How to choose the tier

- Reviewer says "this will break/crash/fail at runtime" → **Standard** minimum, escalate to **Deep** if the claim looks dubious
- Reviewer references how other code in the project does it → **Deep** (actually go check those references)
- Reviewer suggests a different pattern or approach → **Standard** (check if the current approach is valid and intentional)
- Comment contradicts something visible in the immediate code context → **Deep** (investigate who is right)
- Simple "add a null check" / "rename this" / "fix typo" → **Shallow** (just confirm the issue exists)
- Reviewer makes a claim about library/framework behavior → **Standard** (verify against what the code imports and how it's used)

#### Validity tags

Assign each actionable comment one of these tags:

| Tag             | Meaning                                                                                                                                                                                                                                       |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `VALID`         | The reviewer's concern is correct. The code has the issue they describe. Evidence confirms it.                                                                                                                                                |
| `LIKELY VALID`  | The concern appears correct but cannot be fully verified without running the code or deeper domain knowledge.                                                                                                                                 |
| `DISPUTED`      | The reviewer's concern conflicts with evidence in the codebase. The code may already handle the case, or project conventions differ from what the reviewer suggests. **Must include reasoning and cite evidence (file paths, line numbers).** |
| `INVALID`       | The reviewer is demonstrably wrong. The concern is already addressed in the code, or the claim is factually incorrect. **Must include evidence.**                                                                                             |
| `NEEDS CONTEXT` | Cannot determine validity without domain knowledge, runtime behavior, or information not available in the codebase. Flag for the user to decide.                                                                                              |

#### Validation guidelines

- **Always read the actual current file** at the referenced path and line. Never validate from the diff hunk or comment text alone — the code may have changed since the review.
- **Check the surrounding scope.** A comment about a missing null check is invalid if the null check exists in the enclosing function, a wrapper, or a caller. Don't look at the line in isolation.
- **Verify reviewer references.** If the reviewer says "look at how `processOrder` does it in `orders.ts`" — go read that code and check if the comparison is actually apt.
- **Distinguish style from correctness.** If the reviewer says "use X instead of Y" and both are functionally equivalent, check if the project has an established convention. If Y is the convention, tag as `DISPUTED` and cite examples.
- **Check for already-addressed concerns.** Sometimes reviewers comment on an earlier commit and the PR author already fixed it in a later commit but the thread wasn't resolved. Read the current state of the file, not the diff state.
- **Be honest about uncertainty.** Use `NEEDS CONTEXT` rather than guessing. False confidence in either direction is worse than admitting you don't know.

### 5. Present the summary

Output a structured summary in this format:

```
## PR #<number>: <title>
<url>

### Reviews
- **@reviewer** — `CHANGES_REQUESTED` — "<body excerpt>"
- **@reviewer** — `APPROVED`

### Actionable — Code Changes (<count>)
1. `src/foo.ts:42` — **@reviewer**: "<comment excerpt>"
   [VALID] — `user` can be undefined here; no null guard exists
2. `src/bar.ts:15` — **@reviewer**: "<comment excerpt>"
   [DISPUTED] — The shared helper at `src/utils/helper.ts:28` doesn't handle the async case needed here; current implementation is correct
   *[nit/optional]* ← only if applicable
3. `src/baz.ts:99` — **@reviewer**: "<comment excerpt>"
   [INVALID] — Error handling already exists in the caller at `src/api/client.ts:55` which wraps this in a try/catch

### Actionable — Questions (<count>)
4. `src/baz.ts:8` — **@reviewer**: "<question excerpt>"
   [NEEDS CONTEXT] — Cannot determine without knowing the expected API contract

### Non-actionable (<count>)
- [Praise] **@reviewer**: "<excerpt>"
- [Info] **@reviewer**: "<excerpt>"

### Skipped — Resolved (<count>)
- `src/old.ts:10` — **@reviewer**: "<excerpt>" *(resolved)*
- `src/other.ts:5` — **@reviewer**: "<excerpt>" *(outdated + resolved)*
```

**Numbering**: Number the actionable items sequentially across both code-change and question categories so the user can reference them by number.

**Validity tags are mandatory** on every actionable item. Each tag must include a one-line justification. `DISPUTED` and `INVALID` tags must cite specific file paths and line numbers as evidence.

### 6. Prompt for action

After presenting the summary, ask the user what they'd like to do:

- **Address all** actionable code-change comments
- **Address specific items** by number (e.g., "1, 3, 5")
- **Skip** — they only wanted the summary

Highlight any `DISPUTED` or `INVALID` items and recommend the user consider skipping them. Make it clear these are recommendations, not decisions — the user has final say.

Wait for the user's response before proceeding. Do NOT make any code changes without explicit confirmation.

### 7. Execute changes

For each comment the user selected:

1. Read the relevant file and understand the surrounding code context
2. Read the full comment thread to understand exactly what the reviewer is asking for
3. Make the code change
4. Briefly note what was changed and why

After all selected changes are made, output a summary:

```
## Changes Made

1. `src/foo.ts:42` — <brief description of what was changed>
2. `src/bar.ts:15` — <brief description of what was changed>
```

Do NOT commit the changes. The user will review and commit themselves.

## Rules

- **Never resolve threads on GitHub.** That is the reviewer's prerogative. This skill only makes local code changes.
- **Never act without user confirmation.** Always present the plan first (Step 5-6) and wait for explicit go-ahead before making any code changes.
- **Fetch all pages.** Do not stop at the first page of results. Always check `hasNextPage` and paginate until all data is fetched.
- **Preserve the reviewer's intent.** When making code changes, stay faithful to what the reviewer asked for. If the request is ambiguous, note the ambiguity to the user rather than guessing.
- **Skip bot comments.** If a comment author is clearly a bot (e.g., `github-actions[bot]`, `codecov[bot]`), exclude it from categorization — it's noise.
- **Thread-level categorization.** Categorize at the thread level, not the individual comment level. A thread is one conversation — use the full context of all comments in the thread to determine the category and current state.
- **Show file paths and line numbers.** Always include the file path and line number for inline review comments so the user can cross-reference.
- **Always validate against current code.** Never assess a comment's validity based solely on the diff hunk or the comment text. Always read the actual file at the referenced path and line before assigning a validity tag.
- **Cite evidence for DISPUTED and INVALID tags.** Every `DISPUTED` or `INVALID` tag must reference specific file paths and line numbers that support the assessment. Unsupported claims of invalidity are not acceptable.
- **Be honest about uncertainty.** If you cannot determine whether a comment is valid without domain knowledge, runtime testing, or information not in the codebase, use `NEEDS CONTEXT`. Do not guess.
- **Adaptive validation depth.** Scale investigation effort to the comment's complexity. Do not waste time doing deep codebase searches for a typo fix. Do not shallow-validate a claim that something "will crash in production."
- **Do not dismiss reviewer expertise.** A `DISPUTED` or `INVALID` tag means you found concrete evidence the reviewer is wrong. Disagreeing with a reviewer's opinion or style preference without codebase evidence is not grounds for these tags — use `NEEDS CONTEXT` instead.

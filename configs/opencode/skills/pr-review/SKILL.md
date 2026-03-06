---
name: pr-review
description: Fetch and address PR review comments. Validates comment accuracy against the codebase, categorizes as actionable or informational, skips resolved threads, and makes code changes.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Question(*)
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

After presenting the summary, use the **Question tool** to let the user select which items to address. Use a single question with `multiple: true` so the user can pick any combination. Each actionable item becomes an option.

For any `DISPUTED` or `INVALID` items, append "(recommended: skip)" to the description to signal your recommendation — but the user has final say.

Example Question tool call:

```json
{
  "questions": [
    {
      "header": "Select items to address",
      "question": "Which review comments should I address?",
      "multiple": true,
      "options": [
        {
          "label": "#1 foo.ts:42",
          "description": "[VALID] Add null guard for `user` — @reviewer"
        },
        {
          "label": "#2 bar.ts:15",
          "description": "[DISPUTED] Change to shared helper (recommended: skip) — @reviewer"
        }
      ]
    }
  ]
}
```

The user can select any subset, or type a custom answer. If the user selects nothing, treat it as "skip" — they only wanted the summary.

Do NOT make any code changes without explicit confirmation.

### 7. Propose, apply, and verify changes

Process each comment the user selected in Step 6 **one at a time**. For each comment, complete the full propose-apply-verify cycle before moving to the next.

#### 7a. Propose

1. Read the relevant file and understand the surrounding code context
2. Read the full comment thread to understand exactly what the reviewer is asking for
3. Formulate a specific, concrete proposal describing exactly what will change

Present the proposal in this format:

```
### Comment #<N>: `<file>:<line>` — @<reviewer>: "<comment excerpt>"
[<VALIDITY TAG>]

**Proposed solution:**
<Describe the exact change: which lines, what gets added/removed/modified,
and why this approach addresses the reviewer's concern. If following an
existing pattern in the codebase, cite it.>

**Alternative approaches:**
<Only include this section if there are multiple reasonable approaches.
Briefly list them with a recommendation.>
```

Then use the **Question tool** to get the user's decision:

```json
{
  "questions": [
    {
      "header": "Comment #<N>",
      "question": "How should I handle this proposed change?",
      "options": [
        { "label": "Approve", "description": "Apply the change as proposed" },
        {
          "label": "Skip",
          "description": "Do not address this comment, move to the next"
        }
      ]
    }
  ]
}
```

The Question tool's built-in custom answer option allows the user to type modified instructions instead of selecting Approve/Skip. If the user types a custom answer, treat it as modification instructions — revise the proposal accordingly and re-present for confirmation.

Wait for the user's response:

- **Approve** — proceed to apply the change
- **Custom text** — the user provides adjusted instructions; revise the proposal and re-present
- **Skip** — do not address this comment; move to the next one

#### 7b. Apply

If approved, make the code change exactly as proposed (or as modified by the user).

#### 7c. Verify

Immediately after applying the change, show the result so the user can verify it:

1. Run `git diff` on the affected file(s) to show the raw diff of what changed
2. Present a brief description alongside the diff

```
### Applied: Comment #<N> — `<file>:<line>`

<brief description of what was changed and why>

\`\`\`diff
<output of git diff for the affected file(s)>
\`\`\`
```

Then use the **Question tool** to get the user's verdict:

```json
{
  "questions": [
    {
      "header": "Comment #<N> applied",
      "question": "Keep this change?",
      "options": [
        {
          "label": "Accept",
          "description": "Keep the change and move to the next comment"
        },
        {
          "label": "Undo",
          "description": "Revert the change and skip this comment"
        },
        {
          "label": "Redo",
          "description": "Revert and propose a different approach"
        }
      ]
    }
  ]
}
```

Handle the user's response:

- **Accept** — the change is kept; move to the next comment
- **Undo** — revert the change (e.g., `git checkout -- <file>`), mark this comment as skipped, and move on
- **Redo** — revert the change, then go back to Step 7a for this comment to propose a different approach

#### 7d. Repeat

Continue the loop for every selected comment. After all comments have been processed, output a final summary:

```
## Changes Made

1. `src/foo.ts:42` — <brief description of what was changed>
2. `src/bar.ts:15` — <brief description of what was changed>

## Skipped (by user)
- #3 `src/baz.ts:99` — skipped during proposal review
- #5 `src/qux.ts:12` — undone during verification
```

Do NOT commit the changes. The user will review and commit themselves.

### 8. Respond to PR comments

After all code changes are finalized, offer to post replies on the PR threads. This step is optional — the user may decline entirely.

#### 8a. Draft replies

For each comment that was processed in Step 7 (whether addressed, skipped, or disputed), draft an appropriate reply:

**For comments that were addressed with a code change:**

- Briefly describe what was changed and reference the specific fix (file, line)
- Keep it concise — the reviewer can look at the updated diff for details
- Example: _"Fixed — wrapped the `fetch()` call in a try/catch, matching the pattern in `src/api/client.ts:55`."_

**For `DISPUTED`/`INVALID` comments the user chose to skip:**

- Draft a respectful rebuttal explaining why the current code is correct
- Cite the evidence found during validation (file paths, line numbers, patterns)
- Keep it informative, not argumentative
- Example: _"This case is already handled — the caller at `src/api/client.ts:55` wraps this in a try/catch that catches and logs `ApiError`. Adding a duplicate catch here would suppress the error before it reaches the centralized handler."_

**For `question` comments:**

- Draft an answer based on what was learned during validation and code reading
- If a code change was also made in response, mention it
- Example: _"We went with the inline approach here because the shared helper doesn't support async iteration (see `src/utils/helper.ts:28`). Refactoring the helper is tracked in #456."_

**For comments that were skipped without a rebuttal:**

- Do not draft a reply. Silence is fine.

#### 8b. Recommend thread resolution

For each drafted reply, recommend whether to also resolve the thread:

| Situation                                                           | Recommendation                                                         |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Code change was made that directly and fully addresses the comment  | **Recommend resolve**                                                  |
| Question was answered with evidence                                 | **Recommend resolve**                                                  |
| Nit/optional comment was addressed                                  | **Recommend resolve**                                                  |
| Posting a rebuttal for a `DISPUTED` comment                         | **Do NOT resolve** — let the reviewer evaluate the response and decide |
| Posting a rebuttal for an `INVALID` comment                         | **Do NOT resolve** — let the reviewer evaluate the response and decide |
| Comment had multiple concerns and only some were addressed          | **Do NOT resolve** — the thread is not fully addressed                 |
| The fix was partial or the user modified the solution significantly | **Do NOT resolve** — let the reviewer re-evaluate                      |

#### 8c. Present and confirm

Present all drafted replies together for review. For each reply, show the draft as text:

```
### Reply to Comment #<N>: `<file>:<line>` — @<reviewer>
**Draft reply:**
> <the drafted reply text>

**Resolve thread?** <Yes (recommended) / No>
```

Then use the **Question tool** to get the user's decision:

```json
{
  "questions": [
    {
      "header": "Reply #<N>",
      "question": "Post this reply?",
      "options": [
        {
          "label": "Post",
          "description": "Post the reply without resolving the thread"
        },
        {
          "label": "Post + Resolve",
          "description": "Post the reply and resolve the thread"
        },
        {
          "label": "Skip",
          "description": "Do not post a reply for this comment"
        }
      ]
    }
  ]
}
```

The Question tool's built-in custom answer option allows the user to type revised reply text. If the user types a custom answer, treat it as the edited reply — update the draft and re-present for confirmation.

Handle the user's response on each reply:

- **Post** — post the reply without resolving the thread
- **Post + Resolve** — post the reply and resolve the thread
- **Custom text** — the user provides revised text; update and re-present for confirmation
- **Skip** — do not post a reply for this comment

#### 8d. Post replies

For approved replies, use the GitHub GraphQL API:

**Reply to a review thread:**

```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId,
      body: $body
    }) {
      comment { id url }
    }
  }
' -f threadId="$THREAD_ID" -f body="$REPLY_BODY"
```

**Resolve a review thread (if user approved):**

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { isResolved }
    }
  }
' -f threadId="$THREAD_ID"
```

**Reply to an issue-level comment (not in a review thread):**

```bash
gh api repos/{owner}/{repo}/issues/{number}/comments -f body="$REPLY_BODY"
```

After posting, confirm each reply was posted successfully and show the URL of the posted comment.

## Rules

- **Never act without user confirmation.** Present the summary (Step 5-6), get selection, propose each solution individually (Step 7a), wait for approval before applying (Step 7b), wait for verification after applying (Step 7c), and get approval before posting any replies (Step 8c). Every mutation — code change, PR reply, thread resolution — requires explicit user consent.
- **Stop after each change.** Execute one code change at a time, show the `git diff`, and wait for the user to accept/undo/redo before moving to the next comment. Never batch multiple changes.
- **Never post PR replies without user approval.** Draft all replies and present them for review before posting. The user controls what gets posted on their behalf.
- **Never resolve threads without user approval.** Recommend resolution when appropriate, but always let the user make the final call. Resolving a thread the reviewer should re-evaluate is worse than leaving it open.
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
- **Proposals must be specific.** "Fix the error handling" is not a proposal. Name the exact lines being changed, the exact modification, and cite the pattern being followed if applicable.
- **Reply content must reference the actual change.** Do not post generic "Fixed" replies. Reference the specific file, line, and what was modified so the reviewer can verify without hunting through the diff.

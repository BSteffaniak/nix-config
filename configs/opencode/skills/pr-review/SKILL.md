---
name: pr-review
description: Review a pull request — analyze the diff, draft inline review comments, and submit a GitHub review. You are the reviewer.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(sqlite3:*), Question(*)
---

## Purpose

Review a pull request as a code reviewer. Analyze the diff and surrounding code context, identify issues and areas for improvement, draft inline review comments, and submit them as a single atomic GitHub review — all with user approval before anything is posted.

## Steps

### 1. Determine working context

Determine whether the current working directory is a local checkout of the PR's repository. This step performs **detection only** — do not clone anything. This skill never needs a local clone.

- If the user provides a PR URL, parse `owner/repo` and `number` from the URL pattern `github.com/{owner}/{repo}/pull/{number}`.
- If the user provides a PR number (no URL), the current directory **must** be the target repo — run `gh repo view --json nameWithOwner --jq .nameWithOwner` to extract `owner/repo`.
- If neither is provided, auto-detect from the current branch:
  ```bash
  gh pr view --json number,url,title,headRefName,baseRefName
  ```

After identifying the PR, determine whether the current directory is a checkout of the target repo:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null
```

Compare the result (case-insensitive) against the `owner/repo` extracted from the PR. Record the result as one of:

- **`local`** — CWD is a checkout of the target repo. Use local file reads for code context.
- **`remote`** — CWD is not the target repo. Use the GitHub API for all file reads.

If the context is `remote`, also extract the PR's `headRefName` and `baseRefName` for use in API-based file reads.

If no PR is found, inform the user and stop.

#### Parse review depth

Check the user's invocation for a depth flag:

- `--quick` or "quick review" → **quick** mode (diff + immediate context only)
- `--deep`, "thorough review", or no flag → **deep** mode (default — full file reads, imports, architecture)

### 2. Fetch PR data

Gather all the information needed to perform the review.

#### PR metadata

```bash
gh pr view {number} -R {owner}/{repo} --json number,url,title,body,author,headRefName,baseRefName,headRefOid,additions,deletions,changedFiles
```

Store the `headRefOid` (HEAD commit SHA) — this is needed for posting inline comments.

#### PR diff

```bash
gh pr diff {number} -R {owner}/{repo}
```

#### Changed files list

```bash
gh pr diff {number} -R {owner}/{repo} --name-only
```

#### Existing reviews and comments

Fetch existing reviews to avoid duplicating feedback that has already been given:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviews(first: 100) {
          nodes {
            state
            body
            author { login }
          }
        }
        reviewThreads(first: 100) {
          nodes {
            isResolved
            path
            line
            comments(first: 100) {
              nodes {
                body
                author { login }
              }
            }
          }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER"
```

Paginate if needed (check `pageInfo.hasNextPage`).

### 3. Analyze the diff

Read and understand every changed file in the context of the broader codebase. The depth of analysis depends on the mode selected in Step 1.

#### Reading files for context

**If context is `local`:**

Read files directly from the local checkout.

**If context is `remote`:**

Read files via the GitHub API. **Do NOT clone the repo.** This skill never requires a local clone.

- **Read a specific file at the PR's head ref:**

  ```bash
  gh api repos/{owner}/{repo}/contents/{path}?ref={headRefName} --jq '.content' | base64 -d
  ```

- **Read a file at the base ref** (to understand what changed):

  ```bash
  gh api repos/{owner}/{repo}/contents/{path}?ref={baseRefName} --jq '.content' | base64 -d
  ```

- **Search for patterns across the repo** (for convention checking):
  ```bash
  gh api search/code -X GET -f q='{pattern}+repo:{owner}/{repo}' --jq '.items[].path'
  ```

#### Quick mode

For each changed file:

1. Read the diff hunks
2. Read 10–15 lines above and below each hunk for immediate context
3. Identify issues visible from the diff and immediate surroundings

#### Deep mode (default)

For each changed file:

1. Read the full file (or relevant sections for files over 500 lines)
2. Read imports, type definitions, and interfaces used by the changed code
3. Read functions/methods that call or are called by the changed code (follow one level of references)
4. Understand the architectural context — what role does this file play, what patterns does it follow
5. Check for consistency with project conventions (naming, error handling patterns, test patterns)

For both modes, also:

- Read the PR description to understand the author's intent
- Review commit messages if they provide useful context

#### Issue identification

Analyze across these categories:

| Category         | What to look for                                                                       |
| ---------------- | -------------------------------------------------------------------------------------- |
| `bug`            | Logic errors, off-by-ones, null/undefined access, race conditions, wrong return values |
| `security`       | Injection vectors, auth bypass, secrets exposure, unsafe deserialization               |
| `performance`    | Unnecessary allocations, N+1 patterns, missing memoization, unbounded operations       |
| `error-handling` | Swallowed errors, missing catch blocks, unhelpful error messages, unhandled edge cases |
| `logic`          | Dead code, unreachable branches, contradictory conditions, missing cases               |
| `readability`    | Confusing naming, overly complex expressions, missing or misleading comments           |
| `style`          | Inconsistency with surrounding code conventions (indentation, naming patterns)         |

#### Severity levels

Assign each finding a severity that maps to its review impact:

- **blocking** — Will cause incorrect behavior, data loss, or security vulnerability. Must be fixed before merge. (Maps to REQUEST_CHANGES.)
- **suggestion** — Suboptimal pattern, likely to cause problems, or missing important handling. Should be fixed. (Strong recommendation.)
- **nit** — Style issue, minor readability concern, optional improvement. Take it or leave it.
- **question** — Need clarification from the author. May or may not imply a change.

#### De-duplication

Before recording a finding, check the existing reviews fetched in Step 2:

- If another reviewer has already flagged the **same concern** on the **same line** and it is **unresolved**, skip it — do not duplicate.
- If the concern was flagged and **resolved**, check whether the resolution is adequate. Only re-flag if the fix is insufficient.
- If the concern was flagged but on a **different line** or with **different reasoning**, it's not a duplicate — include it.

### 4. Draft the review

Compose the review as a set of inline comments plus a summary body.

#### Inline comments

For each finding, draft an inline comment. Each comment includes:

- **File path and line number** — the specific line in the diff to attach the comment to
- **Severity** (internal only) — `blocking`, `suggestion`, `nit`, or `question`. Used for ordering and triage in the local presentation. **Never included in the posted comment text.**
- **Comment body** — the actual text that will be posted to GitHub

**Comment writing guidelines:**

All posted comment text must follow the [voice and tone guide](../_shared/voice-and-tone.md). Key points:

- Get to the point immediately. First sentence carries the payload.
- Never prefix comments with severity tags like `[blocking]` or `[nit]`. The severity comes through in how you write it, not a label.
- Concrete suggestions for blocking/suggestion-level comments. Either prose or a code snippet.
- One sentence is often enough for nits.
- Reference specific evidence. "`UserService` on line 45 expects a non-nil user" not "this might break something".
- Don't repeat information visible in the diff.

#### Summary body

Draft a summary review body. Keep it short and natural. A couple sentences covering the overall impression and the most important concerns. The inline comments carry the detail, so the summary doesn't need to enumerate everything.

All posted text must follow the [voice and tone guide](../_shared/voice-and-tone.md).

#### Recommended review state

Based on the findings, recommend a review state:

- **APPROVE** — No blocking issues, suggestions are minor
- **REQUEST_CHANGES** — At least one blocking issue that must be fixed
- **COMMENT** — No blocking issues, but substantial suggestions worth discussing

### 5. Present the draft review

Show the complete draft review for user approval before posting.

#### Summary section

```
## Draft Review: PR #<number> — <title>

**Recommended state:** <APPROVE / REQUEST_CHANGES / COMMENT>

### Summary

<draft summary body>
```

#### Inline comments

For each inline comment, present using the [embedded ascii-art format](../_shared/code-comment-format.md). Show the severity in the **local header only** (for the user's triage), not in the comment body that will be posted:

```
### Comment #<N>: `<file>:<line>` [<severity>]
```

Then the ascii-art block showing the code context and the draft comment in a box below the target line(s). The comment body shown here is exactly what will be posted to GitHub. For example:

````
```
   40 │ async function getUser(id: string) {
   41 │   const result = await db.query(id);
   42 │   return result.name;
      │
      │  ┌─ Draft comment ─────────────────────────────────
      │  │ `result` can be undefined if the query returns
      │  │ no rows, this'll throw at `.name`. needs a
      │  │ null check
      │  └─────────────────────────────────────────────────
      │
   43 │ }
```
````

#### User editing

Use the **Question tool** with `multiple: true` to let the user select which comments to include in the review:

```json
{
  "questions": [
    {
      "header": "Select review comments",
      "question": "Which comments should be included in the review?",
      "multiple": true,
      "options": [
        {
          "label": "#1 foo.ts:42 (blocking)",
          "description": "Null guard missing on query result"
        },
        {
          "label": "#2 bar.ts:15 (suggestion)",
          "description": "Error message should include the request ID"
        },
        {
          "label": "#3 baz.ts:88 (nit)",
          "description": "Inconsistent naming: `getData` vs `fetchData` elsewhere"
        }
      ]
    }
  ]
}
```

The user can:

- Deselect comments to exclude them
- Type custom text to modify specific comments (e.g., "edit #2 to say..." or "drop the nits")

If the user modifies any comments, update the drafts and re-present the affected comments for confirmation.

Then ask for the review state:

```json
{
  "questions": [
    {
      "header": "Review state",
      "question": "Submit this review as:",
      "options": [
        {
          "label": "Comment",
          "description": "General feedback, no explicit approval or rejection"
        },
        {
          "label": "Approve",
          "description": "Approve the PR with these comments"
        },
        {
          "label": "Request Changes",
          "description": "Request changes before this can be merged"
        }
      ]
    }
  ]
}
```

If the user selects nothing (no comments and no state), treat it as "cancel" — do not submit a review.

### 6. Submit the review

Post the review as a single atomic GitHub review using the `addPullRequestReview` GraphQL mutation. This submits all inline comments together as one review — not as individual comments.

First, get the PR's GraphQL node ID:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        id
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER" --jq '.data.repository.pullRequest.id'
```

Then submit the review:

```bash
gh api graphql -f query='
  mutation($prId: ID!, $body: String!, $event: PullRequestReviewEvent!, $commitOID: GitObjectID!, $comments: [DraftPullRequestReviewComment!]) {
    addPullRequestReview(input: {
      pullRequestId: $prId
      body: $body
      event: $event
      commitOID: $commitOID
      comments: $comments
    }) {
      pullRequestReview {
        id
        url
      }
    }
  }
' -f prId="$PR_NODE_ID" \
  -f body="$SUMMARY_BODY" \
  -f event="$EVENT" \
  -f commitOID="$HEAD_COMMIT_SHA" \
  -f comments="$COMMENTS_JSON"
```

Where `$EVENT` is one of `COMMENT`, `APPROVE`, or `REQUEST_CHANGES`, and `$COMMENTS_JSON` is a JSON array of objects:

```json
[
  {
    "path": "src/foo.ts",
    "line": 42,
    "body": "`result` can be undefined if the query returns no rows, this'll throw at `.name`. needs a null check"
  }
]
```

**Note on line numbers:** The `line` field must refer to a line in the **diff** (a line that was added or is within the diff context). If the target line is not in the diff, find the nearest line in the diff hunk and adjust the comment to reference the correct location.

After posting, confirm success and show the review URL:

```
Review submitted: <url>
State: <COMMENT / APPROVE / REQUEST_CHANGES>
Comments: <N> inline comments
```

## Rules

- **Follow the [voice and tone guide](../_shared/voice-and-tone.md) for all posted text.** Every comment body and summary body that gets posted to GitHub must sound like a human wrote it. Severity tags, bracket prefixes, em-dashes, filler phrases, and fake politeness are never acceptable in posted text.
- **Severity is internal, not posted.** Severity levels (blocking, suggestion, nit, question) are used for ordering findings and helping the user triage in the local presentation. They are never included in the comment text posted to GitHub.
- **Never clone the repository.** This skill is entirely read-only with respect to the filesystem. All code reads happen via local file reads (if in the repo) or the GitHub API (if remote). No cloning, no checkouts, no file modifications.
- **Never post without user approval.** The draft review is presented in full (Step 5) and the user explicitly selects which comments to include and which review state to use before anything is submitted.
- **Submit as a single atomic review.** All comments are posted together via `addPullRequestReview`, not as individual comment posts. This gives the PR author a single notification with all feedback, not a stream of individual comments.
- **Do not duplicate existing feedback.** Check existing reviews and comments before drafting. If another reviewer has already flagged the same issue on the same line, skip it.
- **Severity must be accurate.** Do not inflate severity to get attention. `blocking` means the code is broken or insecure, not that you prefer a different style. Misclassifying nits as blocking erodes trust.
- **Verify before commenting.** Read the actual file before drafting a comment. Do not comment on assumptions. If you cannot verify a concern, either investigate deeper or skip it.
- **Respect the author's approach.** If the author chose a valid approach that differs from your preference, that is not a finding. Only flag it if you can cite a concrete problem (correctness, performance, maintainability) or a project convention that contradicts it.
- **Keep comments actionable.** Every blocking and suggestion comment must include a concrete suggestion. "This could be better" is not actionable.
- **Questions are genuine.** Use question severity when you genuinely need information to evaluate the code, not as a passive-aggressive way to suggest a change. If you already know the answer, make it a suggestion instead.
- **Deep analysis by default.** Unless the user explicitly requests a quick review, read full files and follow references to understand the code in context. Surface-level diff scanning misses the most important issues.
- **Scale effort to PR size.** A 5-line PR does not need 20 minutes of analysis. A 500-line PR across 15 files warrants thorough investigation. Use judgment.
- **The summary body is not a recap.** The summary should highlight the most important points and give an overall read. Do not enumerate every comment in the summary.
- **Positive feedback must be genuine.** If the code is well-written, say so briefly. Do not fabricate praise to soften criticism.

---
name: pr-annotate
description: Analyze a PR's changes and post concise guiding comments to help reviewers understand context, decisions, and complexity.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Question(*)
---

## Purpose

Analyze a pull request's diff, identify areas where a reviewer would benefit from author-provided context, draft concise guiding comments, and post them as individual review comments on the PR. The goal is to preemptively answer "why?" questions and steer reviewer attention — not to narrate the diff.

## Steps

### 1. Identify the PR

- If the user provides a PR number or URL as an argument, use that.
- Otherwise, auto-detect from the current branch:
  ```bash
  gh pr view --json number,url,title,headRefName,baseRefName,headRefOid
  ```
- If no PR is found for the current branch, inform the user and stop.
- Extract `owner` and `repo` from the repo context:
  ```bash
  gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
  ```
- Store the `headRefOid` (HEAD commit SHA) — this is needed for posting comments.

### 2. Fetch the diff and understand the changes

#### Get the diff

```bash
gh pr diff $PR_NUMBER
```

#### Get changed file list and commit history

```bash
gh pr view $PR_NUMBER --json files,commits --jq '.files[].path'
git log $(git merge-base HEAD $BASE_BRANCH)..HEAD --oneline
```

#### Read full file context

For each changed file, read the actual current file contents — not just the diff hunks. Annotations require understanding the surrounding code, not just the changed lines.

Focus reading effort on files with non-trivial changes. Skip lockfiles, generated code, and files where the diff is purely mechanical (formatting, renames with no logic changes).

### 3. Analyze and propose annotation areas

Analyze the diff and file context to identify locations where a reviewer comment from the author would genuinely help. Look for:

- **Non-obvious decisions** — code that does something a specific way where the reason isn't self-evident from the code alone
- **Complex logic** — dense algorithms, regex, tricky conditionals, non-obvious control flow
- **Context pointers** — changes that relate to or depend on code elsewhere that reviewers should be aware of
- **Known limitations** — intentional shortcuts, tech debt, or follow-up work that reviewers might otherwise flag
- **Review guidance** — areas that need careful review vs. areas that are safe to skim

#### What makes a good annotation

- A reviewer would likely ask "why?" or "what does this do?" without the comment
- There is context only the author would know (design decisions, constraints, prior discussion)
- The comment prevents a likely back-and-forth in review
- The annotation is on a line that is part of the PR diff (GitHub only allows review comments on diff lines)

#### What to skip

- Self-explanatory changes — do not narrate the obvious
- Every file — be selective, not exhaustive
- Trivial additions, deletions, or renames
- Lockfiles, generated code, CI config changes (unless genuinely surprising)
- Anything where the diff hunk + surrounding code tells the full story

**Aim for quality over quantity.** A PR with 3 well-placed annotations is better than one with 12 that mostly state the obvious.

#### Present the proposals

First, output a summary header:

```
## PR #<number>: <title>
<url>
```

Then use the **Question tool** to let the user select which annotations to draft. Use a single question with `multiple: true` so the user can pick any combination. Each option should have:

- **label**: `#<N> <file>:<line>` (short, fits in the selection UI)
- **description**: The one-line description of what the comment would explain

Example Question tool call:

```json
{
  "questions": [
    {
      "header": "Select annotations",
      "question": "Which annotations should I draft?",
      "multiple": true,
      "options": [
        {
          "label": "#1 foo.ts:42",
          "description": "Why explore-level filters are applied as a separate step before local filters"
        },
        {
          "label": "#2 bar.ts:15-20",
          "description": "Why filtered-out IDs are sorted and compared by value rather than using Set equality"
        }
      ]
    }
  ]
}
```

The user can select any subset, or type a custom answer. If the user selects nothing (empty response), treat it as "none" and stop.

Do NOT draft or post anything without selection.

### 4. Draft comments one-by-one

For each annotation the user selected, draft a comment and present it for approval. Process them **one at a time** — do not batch.

#### Drafting rules

All posted annotation text must follow the [voice and tone guide](../_shared/voice-and-tone.md). Additionally:

- **1-3 sentences max.** Rarely more.
- **No filler.** Cut "It's worth noting that...", "For context, ...", "Note that...", "This is because...". Just state the thing.
- **Get straight to the point.** First word should carry meaning.
- **Write like a terse inline code comment**, not a paragraph or essay.
- **One idea per comment.** If two things need explaining, they should be two separate annotations.
- **If it can be said in one sentence, use one sentence.**
- **Do not repeat what the code already says.** The reviewer can read the diff. Explain what the diff doesn't show.

#### Present each draft

Present each draft using the [embedded ascii-art format](../_shared/code-comment-format.md). Show the relevant code with line numbers and the draft comment in a box below the target line(s), using the "draft annotation" variant.

Output the header, then the ascii-art block:

```
### Annotation #<N>: `<file>:<line>`
```

Followed by the ascii-art code+comment block (see the shared format spec for the full visual specification and examples).

Then immediately use the **Question tool** to get the user's decision:

```json
{
  "questions": [
    {
      "header": "Annotation #<N>",
      "question": "Post this comment to the PR?",
      "options": [
        { "label": "Post", "description": "Approve and queue for posting" },
        { "label": "Skip", "description": "Do not post this annotation" }
      ]
    }
  ]
}
```

The Question tool's built-in custom answer option allows the user to type edited comment text instead of selecting Post/Skip. If the user types a custom answer, treat it as the revised comment text — re-present the updated draft and ask again.

Wait for the user's response on each draft before moving to the next:

- **Post** — queue this comment for posting
- **Custom text** — user provided revised text; update the draft and re-present for confirmation
- **Skip** — do not post this annotation; move to the next one

### 5. Post approved comments

After all drafts have been reviewed, post each approved comment to the PR.

#### Determine the correct diff position

The `line` parameter must reference a line in the **right side** of the diff that is part of the PR's changes. Before posting, verify the target line appears in the diff output from Step 2. If a proposed line is not in the diff, find the nearest diff line in the same hunk or skip the annotation.

#### Post each comment

Use the GitHub REST API to post individual review comments:

**Single-line comment:**

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  -f body="$BODY" \
  -f commit_id="$HEAD_SHA" \
  -f path="$FILE_PATH" \
  -F line=$LINE_NUMBER \
  -f side="RIGHT"
```

**Multi-line comment (spanning a range):**

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  -f body="$BODY" \
  -f commit_id="$HEAD_SHA" \
  -f path="$FILE_PATH" \
  -F start_line=$START_LINE \
  -F line=$END_LINE \
  -f start_side="RIGHT" \
  -f side="RIGHT"
```

After each post, confirm success and show the URL of the posted comment.

If a post fails (e.g., the line is not part of the diff), report the error and move on to the next comment. Do not retry unless the user asks.

### 6. Summary

After all comments have been processed, output a final summary:

```
## Annotations Posted (<count>)

1. `src/foo.ts:42` — <brief description> — <url>
2. `src/bar.ts:15` — <brief description> — <url>

## Skipped (<count>)
- #3 `src/baz.ts:99` — skipped by user
- #5 `src/qux.ts:12` — not in diff range
```

## Rules

- **Follow the [voice and tone guide](../_shared/voice-and-tone.md) for all posted text.** Every annotation posted to GitHub must sound like a human wrote it.
- **Never post without explicit user approval.** Every comment must be individually drafted, presented, and approved before posting. No batching, no assumptions.
- **One at a time.** Draft and present one annotation at a time. Wait for the user's response before moving to the next.
- **Conciseness is non-negotiable.** If a draft exceeds 3 sentences, rewrite it shorter. Reviewers will not read walls of text. Dense, informative, terse.
- **Do not annotate the obvious.** If the diff speaks for itself, leave it alone. Annotations should add information the code doesn't already convey.
- **Fewer is better.** Propose only annotations that genuinely help. A PR with zero annotations needed is a valid outcome — say so and stop.
- **Always read the full file context.** Do not draft annotations based solely on diff hunks. Read the surrounding code to avoid comments that miss context visible in the file.
- **Lines must be in the diff.** GitHub only allows review comments on lines that appear in the PR diff (right side). If a target line is not in the diff, either find the nearest diff line in the same hunk or skip the annotation.
- **Use the HEAD commit SHA.** The `commit_id` for posting must be the `headRefOid` from the PR metadata. Using a stale SHA will cause the comment to show as outdated.
- **Skip generated content.** Do not annotate lockfiles, auto-generated code, or purely mechanical changes unless there is something genuinely surprising.
- **Do not editorialize.** Annotations should provide facts, context, and reasoning — not opinions about code quality or self-congratulatory notes.
- **Respect the user's edits.** If the user modifies a draft, post their version exactly. Do not re-edit their words.

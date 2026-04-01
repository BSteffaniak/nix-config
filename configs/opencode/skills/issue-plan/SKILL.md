---
name: issue-plan
description: Read a GitHub issue and plan how to address it. Interactive — fetches issue data, explores the codebase, and drafts a high-level implementation plan.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Read(*), Glob(*), Grep(*), Question(*), Task(*)
---

## Purpose

Read a GitHub issue by URL or reference, fetch its full context (title, body, labels, comments), explore the local codebase for relevant code, and produce a high-level plan for addressing the issue. The plan covers what needs to change and why, identifies key files and areas of the codebase involved, and surfaces risks or open questions. This skill is read-only — it does not modify code or create commits.

## Steps

### 1. Parse issue input

Accept the issue as a URL or shorthand reference. Extract the owner, repo, and issue number.

Supported formats:

- Full URL: `https://github.com/owner/repo/issues/123`
- Short URL: `owner/repo#123`
- Number only: `123` (requires being inside a git repo with a GitHub remote)

If only a number is provided, detect the repo from the local git remote:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

Parse the URL with pattern matching:

```bash
# Extract from URL
echo "https://github.com/owner/repo/issues/123" | sed -E 's|https://github.com/([^/]+)/([^/]+)/issues/([0-9]+)|\1 \2 \3|'
```

If the input cannot be parsed, ask the user to provide a valid GitHub issue URL.

### 2. Fetch issue data

Fetch the full issue context using the GitHub CLI.

#### Issue metadata

```bash
gh issue view {number} -R {owner}/{repo} --json title,body,state,labels,assignees,milestone,createdAt,author,url
```

#### Issue comments

```bash
gh issue view {number} -R {owner}/{repo} --json comments --jq '.comments[] | {author: .author.login, createdAt: .createdAt, body: .body}'
```

#### Linked pull requests (if any)

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        timelineItems(first: 50, itemTypes: [CROSS_REFERENCED_EVENT]) {
          nodes {
            ... on CrossReferencedEvent {
              source {
                ... on PullRequest {
                  number
                  title
                  state
                  url
                }
              }
            }
          }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number=$NUMBER
```

Present a brief summary of what was fetched:

```
Issue #123: "Title here"
Author: @username | State: open | Labels: bug, priority/high
Comments: 5 | Linked PRs: 1 (open)
```

If `gh` is not available or authentication fails, print an error and stop.

### 3. Understand the codebase context

Analyze the issue content (title, body, comments) to identify keywords, file paths, function names, error messages, or other references to the codebase.

Use the Task tool with an explore agent to search the local repo for relevant code:

- **Keywords from the issue** — grep for error messages, feature names, API endpoints, or identifiers mentioned in the issue
- **File paths** — if the issue mentions specific files, read them for context
- **Related patterns** — search for related code patterns (e.g., if the issue mentions a bug in authentication, search for auth-related modules)

Compile a list of relevant areas:

```
Relevant areas identified:
1. src/auth/login.ts (lines 45-80) — login handler mentioned in error trace
2. src/middleware/session.ts — session validation logic
3. tests/auth/ — existing test coverage for auth module
```

#### Gate: Confirm relevant areas

Present the identified areas to the user using the Question tool:

```json
{
  "header": "Relevant areas",
  "question": "I found these areas of the codebase that seem relevant. Should I explore any additional areas?",
  "multiple": true,
  "options": [
    { "label": "Looks good", "description": "Proceed with these areas" }
  ]
}
```

If the user provides custom text naming additional areas to explore, search for those and add them to the context before proceeding.

### 4. Draft the plan

Synthesize the issue context and codebase findings into a high-level implementation plan. Use the following structure:

```markdown
## Plan: <issue title>

**Issue**: <url>
**Status**: <open/closed> | **Labels**: <labels>

### Summary

One paragraph explaining what the issue is asking for and the core problem to solve.

### Approach

Numbered list of high-level steps to address the issue. Each step should explain _what_ to change and _why_, without diving into exact code. Reference specific files or modules where relevant.

1. **Step name** — Description of what to do and why. Relevant area: `path/to/file.ts`
2. **Step name** — Description. Relevant area: `path/to/module/`
3. ...

### Key Files

Bulleted list of files that will likely need changes, with a brief note on what kind of change:

- `path/to/file.ts` — Modify the handler to support X
- `path/to/other.ts` — Add new validation logic
- `tests/path/to/test.ts` — Add test coverage for the new behavior

### Risks & Open Questions

Bulleted list of anything uncertain, risky, or requiring further discussion:

- Does the API need to remain backward-compatible?
- The current implementation of X may conflict with Y
- Need to confirm whether Z is expected behavior
```

If the issue is simple enough that some sections would be empty or trivial, omit them. The plan should be proportional to the issue's complexity.

### 5. Present the plan

Display the full plan to the user. Then ask for their feedback using the Question tool:

```json
{
  "header": "Plan review",
  "question": "How does this plan look?",
  "options": [
    { "label": "Approve", "description": "The plan is good — we're done" },
    {
      "label": "Regenerate",
      "description": "Start the plan over with a different approach"
    }
  ]
}
```

Handle the response:

- **Approve** — Print the final plan and end.
- **Regenerate** — Redraft the plan from scratch with a different approach, re-present.
- **Custom text** — Apply the user's edits or adjustments to the plan, re-present.

Repeat until the user approves.

## Rules

- **Never skip a gate.** Always pause at the codebase context confirmation (Step 3) and plan review (Step 5) gates. Never proceed without user input.
- **Never act without user confirmation.** This skill is read-only and produces a plan. It does not modify files, create branches, or make commits.
- **Truthful analysis only.** Do not fabricate file paths, function names, or codebase details. If a search turns up nothing relevant, say so.
- **Respect user edits.** If the user provides custom text to adjust the plan, apply their changes faithfully without re-editing their words.
- **Proportional plans.** Scale the plan's detail to the issue's complexity. A one-line bug fix does not need five plan sections. Omit sections that would be trivially empty.
- **Require gh CLI.** This skill depends on the GitHub CLI (`gh`) being installed and authenticated. If `gh` is not available, report the error immediately rather than attempting workarounds.
- **Local repo is optional.** If the user is not inside a git repo or the repo doesn't match the issue's repository, skip the codebase exploration step (Step 3) and note that the plan is based solely on the issue content.

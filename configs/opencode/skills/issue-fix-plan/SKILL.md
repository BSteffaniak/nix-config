---
name: issue-fix-plan
description: Read a GitHub issue, analyze it against the local codebase, and propose an implementation plan. Interactive - fetches complete issue context, validates likely impact areas, and produces a reviewable fix plan.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(jq:*), Question(*)
---

## Purpose

Investigate a GitHub issue with `gh`, map the reported behavior to relevant code paths in the current repository, and produce a concrete implementation plan without making code changes.

## Prerequisites

- `gh` is installed and authenticated (`gh auth status`)
- Current directory is the target git repository
- The issue is accessible with the active GitHub credentials

## Steps

### 1. Collect issue target and planning preferences

Gather:

- Issue reference (URL or `owner/repo#number`)
- Plan depth (`quick`, `standard`, or `deep`)
- Whether to include test and rollback guidance

If required input is missing, ask with `Question(*)`.

### 2. Fetch and normalize all available issue context

Collect every available context source before planning.

Primary issue fetch:

```bash
gh issue view <issue> --repo <owner>/<repo> --comments --json number,title,body,state,author,url,labels,assignees,milestone,projectItems,comments
```

Timeline and events:

```bash
gh api repos/<owner>/<repo>/issues/<number>/timeline
gh api repos/<owner>/<repo>/issues/<number>/events
```

Related artifacts (linked PRs, commits, and cross-references) when needed:

```bash
gh api graphql -f query='\
query($owner: String!, $repo: String!, $number: Int!) {\
  repository(owner: $owner, name: $repo) {\
    issue(number: $number) {\
      timelineItems(first: 100, itemTypes: [CROSS_REFERENCED_EVENT]) {\
        nodes {\
          ... on CrossReferencedEvent {\
            source {\
              ... on PullRequest { number title state url }\
              ... on Issue { number title state url }\
            }\
          }\
        }\
      }\
    }\
  }\
}' -f owner='<owner>' -f repo='<repo>' -F number=<number>
```

Normalize with `jq` into:

- Problem statement
- Reproduction evidence from body and comments
- Expected vs actual behavior
- Constraints and environment notes
- Acceptance criteria (explicit and implied)
- Linked artifacts and follow-up references
- Unknowns and missing context

### 3. Run a context completeness gate

Before codebase analysis, verify this checklist:

- Issue body reviewed
- All comments reviewed
- Timeline/events reviewed
- Linked artifacts (PRs, commits, issues) enumerated
- Labels, milestone, and project metadata captured
- Checklists and action items extracted

If any source is unavailable, record that limitation explicitly and continue.

### 4. Build a codebase investigation map

Translate issue signals into repository search targets:

- Domain terms and feature names
- Error strings and logs
- Endpoint names, config keys, and flags
- Candidate file paths or modules mentioned in context

Use git-native commands:

```bash
git grep -n "<pattern>"
git log --oneline -- <path>
git blame -L <start>,<end> <file>
```

Identify candidate files/modules, related tests, and likely regression windows.

### 5. Validate likely root-cause paths

For each candidate path:

1. State the hypothesis
2. Cite supporting evidence from issue context and code
3. Assign confidence (`high`, `medium`, `low`)
4. Note disconfirming evidence

If confidence is low or evidence conflicts, use a `Question(*)` gate to choose whether to continue best-effort, narrow to one hypothesis, or request more reproduction detail.

### 6. Draft the implementation plan

Produce a plan with:

- Objective
- Scope in and out
- Ordered implementation steps (small and reviewable)
- Test strategy (unit, integration, e2e as appropriate)
- Risk assessment and mitigations
- Rollback or feature-flag strategy when relevant
- Open questions requiring confirmation

Reference concrete repository paths where possible.

### 7. Review gate and finalize output

Present the plan and ask via `Question(*)`:

- Approve
- Regenerate (more concise, deeper, or risk-first)
- Custom edits

Apply requested changes and re-present until approved, then print the final markdown plan.

## Rules

- **Read all available issue context first.** Always review body, comments, timeline/events, metadata, and linked artifacts before final planning.
- **No premature planning.** Do not finalize a plan until the context completeness checklist is satisfied or missing sources are explicitly documented.
- **Read-only analysis only.** Never modify files, create commits, open PRs, or post external updates.
- **Evidence over guesswork.** Tie recommendations to issue context or repository evidence.
- **Never skip gates.** Require user confirmation at uncertainty and final review gates.
- **State confidence clearly.** Mark hypotheses and unknowns explicitly; do not present assumptions as facts.
- **Graceful degradation.** If context sources are unavailable, continue with available evidence and list limitations.

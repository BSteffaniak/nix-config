---
name: work-summary
description: Generate a summary of what you accomplished in a given time period. Gathers data from git commits, GitHub PRs, Linear issues, and OpenCode sessions, then produces a polished changelog-style output.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(linear:*), Bash(python3:*), Bash(jq:*), Bash(find:*), Bash(mktemp:*), Bash(date:*), Bash(sort:*), Bash(wc:*), Question(*), Write(*)
---

## Purpose

Gather everything the user personally accomplished in a given time period across all available data sources — git commits, GitHub PRs, Linear issues, and OpenCode session history — present the raw findings for curation, then produce a polished, changelog-style summary that is accurate, professional, and ready to paste into a standup, status update, or changelog.

## Identity

Before gathering any data, resolve the user's identity across all sources. These values are used to filter every query so that only the user's own work appears.

```bash
GIT_AUTHOR_NAME="$(git config user.name)"
GIT_AUTHOR_EMAIL="$(git config user.email)"
```

```bash
GH_USERNAME="$(gh api graphql -f query='{ viewer { login } }' | jq -r '.data.viewer.login')"
```

```bash
LINEAR_USER="$(linear auth whoami 2>&1)"
# Parse the display name and email from the output
```

Store these for use in all subsequent filtering.

## Steps

### 1. Determine time period

If the user provides a time range as an argument when invoking the skill (e.g., "last week", "last 3 days", "since Monday", "2025-03-01 to 2025-03-07"), parse it and resolve to a concrete `SINCE` date in ISO format (`YYYY-MM-DD`).

If no time range is provided, use the **Question tool** to prompt:

```json
{
  "questions": [
    {
      "header": "Time period",
      "question": "What time period should I summarize?",
      "options": [
        { "label": "Today", "description": "Work done today" },
        { "label": "Yesterday", "description": "Work done yesterday" },
        {
          "label": "Last 3 days",
          "description": "Work done in the past 3 days"
        },
        { "label": "Last week", "description": "Work done in the past 7 days" },
        {
          "label": "Last 2 weeks",
          "description": "Work done in the past 14 days"
        },
        {
          "label": "Last month",
          "description": "Work done in the past 30 days"
        }
      ]
    }
  ]
}
```

The Question tool's custom answer option allows the user to type a specific date range. Parse whatever the user provides into a concrete `SINCE` date.

Compute the `SINCE` date using:

```bash
date -v-7d +%Y-%m-%d   # macOS: 7 days ago
date -d '7 days ago' +%Y-%m-%d  # Linux: 7 days ago
```

Store both `SINCE` (ISO date string) and a human-readable label (e.g., "Mar 1-7, 2025") for use in the final output header.

### 2. Discover repositories

Auto-discover git repositories from three sources:

#### a. OpenCode session directories

Query the OpenCode SQLite database for distinct project directories from sessions updated within the time period:

```python
python3 -c "
import sqlite3, json
from datetime import datetime
SINCE_MS = int(datetime.strptime('$SINCE', '%Y-%m-%d').timestamp() * 1000)
conn = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
c = conn.cursor()
c.execute('''SELECT DISTINCT directory FROM session
             WHERE time_updated >= ?
             ORDER BY time_updated DESC''', (SINCE_MS,))
for r in c.fetchall():
    print(r[0])
"
```

#### b. Git repositories and worktrees under ~/GitHub

The user's workflow relies heavily on **git worktrees** — a single repository (e.g., `~/GitHub/monorepo`) with many linked worktree checkouts in a sibling directory (e.g., `~/GitHub/wt-rec/rec-gov-*`). A naive `find -name .git -type d` will miss these because worktrees have a `.git` **file** (not directory) that points back to the main repo's `.git/worktrees/` folder.

Use a two-phase discovery approach:

**Phase 1: Find all git roots** — Scan for both `.git` directories (normal repos) and `.git` files (worktree checkouts):

```bash
# Find normal repos (.git as directory)
find ~/GitHub -maxdepth 3 -name .git -type d 2>/dev/null

# Find worktree checkouts (.git as file)
find ~/GitHub -maxdepth 3 -name .git -type f 2>/dev/null
```

For each result, resolve to the directory containing it (strip the `/.git` suffix).

**Phase 2: Enumerate all worktrees per repo** — For each discovered git directory, resolve its **common git directory** and run `git worktree list` from there to get the complete picture:

```bash
# From any repo or worktree directory:
COMMON_DIR="$(git -C "$DIR" rev-parse --git-common-dir)"
git -C "$DIR" worktree list --porcelain
```

The porcelain output gives structured data:

```
worktree /Users/braden/GitHub/monorepo
HEAD b4ca51de5
branch refs/heads/master

worktree /Users/braden/GitHub/wt-rec/rec-gov-explore-campsite-filtering
HEAD 9782d0157
branch refs/heads/rec-gov-explore-campsite-filtering

worktree /Users/braden/GitHub/wt-rec/rec-gov-better-map-clustering
HEAD 4f2ab51b2
branch refs/heads/rec-gov-show-map-markers-when-focused-always
```

Collect from each entry: worktree path, HEAD commit, branch name.

**Phase 3: Group by common repo** — Multiple worktrees that share the same `--git-common-dir` belong to the same repository. Group them together. The main worktree (the one whose path matches the common dir's parent) is the "primary" entry; the rest are linked worktrees.

#### c. Current working directory

If the current directory is inside a git repo or worktree, include it. Resolve its common git directory to determine which repo group it belongs to.

#### Deduplicate and present

Merge all discovered paths. Deduplicate by **common git directory** (`git rev-parse --git-common-dir`), not by `--show-toplevel` — this correctly groups worktrees that share the same repo but have different toplevel paths.

Strip any directories that are clearly not the user's work repos (e.g., dependencies, caches, prunable worktrees with no recent commits).

Present the discovered repos using the **Question tool** with `multiple: true` so the user can deselect repos they don't want included:

```json
{
  "questions": [
    {
      "header": "Select repos",
      "question": "Which repositories should I include in the summary?",
      "multiple": true,
      "options": [
        {
          "label": "monorepo (18 worktrees)",
          "description": "~/GitHub/monorepo + ~/GitHub/wt-rec/* — branches: master, rec-gov-explore-campsite-filtering, rec-gov-better-map-clustering, ..."
        },
        { "label": "worktree-setup", "description": "~/GitHub/worktree-setup" },
        { "label": "nix config", "description": "~/.config/nix" }
      ]
    }
  ]
}
```

**Group all worktrees from the same repo into a single option.** Show the total worktree count and list a few representative branch names in the description. When selected, all worktrees for that repo are included in the data-gathering phase.

### 3. Gather data

Collect data from all four sources. Run independent queries in parallel where possible.

#### a. Git commits (worktree-aware)

For each selected repo group (which may contain many worktrees), use a **two-pass strategy** to capture all commits efficiently while preserving branch attribution.

**Pass 1: Collect all commits from the main repo** — Run a single `git log --all` from the main repo directory (or any worktree, since `--all` covers all refs). This captures every commit across all branches in one query:

```bash
git -C "$MAIN_REPO_DIR" log --all --author="$GIT_AUTHOR_NAME" --since="$SINCE" --no-merges \
  --format="%h %ad %s %D" --date=short
```

The `%D` format gives ref decorations (branch names, tags) for each commit, which helps attribute commits to branches.

**Pass 2: Map commits to worktree branches** — For commits that don't have a direct ref decoration, determine which branch they belong to by checking which worktree branches contain them:

```bash
# For each worktree branch discovered in Step 2:
git -C "$MAIN_REPO_DIR" log "$BRANCH_NAME" --author="$GIT_AUTHOR_NAME" --since="$SINCE" --no-merges \
  --format="%h" --date=short
```

Build a mapping of commit hash -> branch name(s). If a commit appears on multiple branches (e.g., it's on master and also on a feature branch that was merged), attribute it to the **feature branch** (the more specific context).

**For repos without worktrees** (simple single-directory repos like `worktree-setup` or `nix config`), a plain `git log` suffices:

```bash
git -C "$REPO_DIR" log --author="$GIT_AUTHOR_NAME" --since="$SINCE" --no-merges \
  --format="%h %ad %s" --date=short
```

Collect for each commit: hash, date, subject line, repo name, branch name (from worktree mapping or ref decoration).

#### b. GitHub PRs

Use the GitHub GraphQL API to fetch PRs authored by the user, updated within the time period. Query across all repos the user has access to:

```bash
gh api graphql -f query='
  query($since: DateTime!, $author: String!) {
    search(query: "is:pr author:\($author) updated:>=\($since)", type: ISSUE, first: 100) {
      nodes {
        ... on PullRequest {
          title
          number
          state
          mergedAt
          url
          repository { nameWithOwner }
          headRefName
          additions
          deletions
          commits { totalCount }
        }
      }
    }
  }
' -f since="$SINCE" -f author="$GH_USERNAME"
```

**Important:** The `search` query uses the `updated:>=` qualifier to catch PRs that were active during the period, including those opened earlier but merged/updated within the window.

Collect: PR title, number, state (open/merged/closed), merge date, URL, repo, branch name, additions/deletions, commit count.

#### c. Linear issues

Fetch issues assigned to the user that were updated in the time period:

```bash
linear issue list --mine --updated-after "$SINCE" --include-completed --json 2>/dev/null
```

If the JSON flag is not available, parse the standard output. Alternatively, use the Linear GraphQL API:

```bash
linear api --variables-json "{\"filter\": {\"assignee\": {\"isMe\": {\"eq\": true}}, \"updatedAt\": {\"gte\": \"${SINCE}T00:00:00Z\"}}}" <<'GRAPHQL'
query($filter: IssueFilter!) {
  issues(filter: $filter, first: 100) {
    nodes {
      identifier
      title
      state { name }
      updatedAt
      completedAt
      url
      project { name }
      labels { nodes { name } }
    }
  }
}
GRAPHQL
```

Collect: issue identifier, title, state, completion date, URL, project name, labels.

#### d. OpenCode sessions

Query the SQLite database for sessions active in the time period. Extract session titles and working directories as supplementary context:

```python
python3 -c "
import sqlite3, json
from datetime import datetime
SINCE_MS = int(datetime.strptime('$SINCE', '%Y-%m-%d').timestamp() * 1000)
conn = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
c = conn.cursor()
c.execute('''SELECT id, title, directory, time_created, time_updated
             FROM session
             WHERE time_updated >= ?
             ORDER BY time_updated DESC''', (SINCE_MS,))
for r in c.fetchall():
    created = datetime.fromtimestamp(r[3]/1000).strftime('%Y-%m-%d %H:%M')
    updated = datetime.fromtimestamp(r[4]/1000).strftime('%Y-%m-%d %H:%M')
    print(f'{r[0]}  {r[1]}  {r[2]}  {created}  {updated}')
"
```

OpenCode sessions serve as **supplementary context** — they help identify work that may not have resulted in commits (debugging, research, code review) and help connect commits to higher-level tasks. They are not primary items in the summary unless they represent significant standalone work.

### 4. Deduplicate and organize

#### Group by project area

Analyze all gathered data and group items into logical project areas. Determine groupings from:

- Repository name (e.g., "rec-gov", "monorepo", "nix config")
- Linear project name if available
- Directory patterns

#### Merge related items

A PR, its commits, and the Linear issue it references are **one logical unit of work**, not separate items. Merge them:

1. **Match PRs to commits by branch name.** The PR's `headRefName` (e.g., `rec-gov-explore-campsite-filtering`) corresponds directly to a worktree branch name from Step 2. All commits attributed to that branch in Step 3a belong to that PR. This is the primary matching strategy and is highly reliable for worktree-based workflows where each worktree = one feature branch = one PR.
2. **Match Linear issues to PRs/branches** by scanning PR titles, branch names, and commit messages for issue identifiers (e.g., `ENG-123`, `NDS-456`). Branch names that embed an issue slug are a strong signal.
3. **Match OpenCode sessions to repos/branches** by working directory. A session with directory `~/GitHub/wt-rec/rec-gov-explore-campsite-filtering` maps to that worktree's branch and its associated PR/issue.
4. **Match commits without a PR** — Commits on a worktree branch that has no associated PR are still valid work items. Group them by branch name and present as "X commits on branch Y (no PR yet)."

Each merged item should have:

- A primary description (from the PR title or Linear issue title — whichever is most descriptive)
- Source references: PR URL, commit count, Linear issue ID
- State: merged, open, completed, in-progress
- Scope indicator: additions/deletions from the PR, or commit count

#### Strip noise

Remove from the results:

- Merge commits
- Automated/bot commits
- Trivial formatting-only changes (unless part of a larger effort)
- Duplicate entries from the same work appearing in multiple sources

### 5. Present findings for selection

Show the organized findings grouped by project area. Use the **Question tool** with `multiple: true` so the user can deselect anything that shouldn't appear in the summary.

For each project area, output a header and then list the items as options:

```
### rec-gov (4 items)
```

```json
{
  "questions": [
    {
      "header": "Select items",
      "question": "Which items should I include in the summary? Deselect any that shouldn't be included.",
      "multiple": true,
      "options": [
        {
          "label": "#1 Campsite filtering",
          "description": "PR #42 merged, 12 commits, ENG-123 \u2014 Explore campsite filtering implementation"
        },
        {
          "label": "#2 Remove v2 flag",
          "description": "PR #38 merged, 4 commits \u2014 Clean up explore v2 feature flag"
        },
        {
          "label": "#3 Map clustering",
          "description": "6 commits (no PR yet) \u2014 Better map clustering algorithm"
        },
        {
          "label": "#4 Nix host discovery",
          "description": "3 commits \u2014 Auto-discover hosts from meta.nix files"
        }
      ]
    }
  ]
}
```

All items are pre-selected by default. The user deselects what they don't want.

If there are many items (10+), break the question into multiple questions grouped by project area so the selection UI stays manageable.

### 6. Draft summary

Generate a polished, changelog-style markdown summary from the selected items.

#### Format

```markdown
## Work Summary — <human-readable date range>

### <Project Area 1>

- **<Action verb> <what was done>** — <brief impact or context>. (<references>)
- **<Action verb> <what was done>** — <brief impact or context>. (<references>)

### <Project Area 2>

- **<Action verb> <what was done>** — <brief impact or context>. (<references>)
```

#### Writing guidelines

- **Active voice, strong verbs.** "Implemented", "Refactored", "Fixed", "Removed", "Added", "Migrated", "Consolidated", "Optimized" — not "worked on", "helped with", "was involved in."
- **Specific and concrete.** Name the actual thing: the feature, the component, the endpoint, the system. Not "updated the frontend" but "Added multi-select filtering for campsite amenities in the explore view."
- **Impact framing where natural.** If the impact is clear and non-trivial, include it: "eliminating 200ms of redundant API calls" or "reducing the deploy pipeline from 12 to 4 minutes." But only when it's **true and verifiable** from the data.
- **Scale language to actual scope.** A 3-line config change is "Updated" or "Fixed", not "Overhauled" or "Redesigned." A multi-week feature with 40+ commits across 15 files can be "Implemented" or "Built."
- **No superlatives or filler.** No "significantly improved", "greatly enhanced", "major refactor" unless the data genuinely supports it. Let the specifics speak.
- **References inline.** PR links, Linear issue IDs, and other references go in parentheses at the end of each item. Format: `(PR #42, ENG-123)` or `([PR #42](url), [ENG-123](url))`.
- **Group logically, not chronologically.** Items within a project area should be ordered by significance, not by date. The most impactful work comes first.
- **Merge tiny related items.** Three small bug fixes in the same area can be one bullet: "Fixed edge cases in campsite date validation — null dates, timezone offsets, and DST transitions."

#### In-progress work

Items that are still in progress (open PRs, incomplete Linear issues, uncommitted branches) should be listed in a separate subsection:

```markdown
### In Progress

- **<what's being worked on>** — <current state>. (<references>)
```

### 7. Review and finalize

Present the full draft summary to the user for review using the **Question tool**:

```json
{
  "questions": [
    {
      "header": "Review summary",
      "question": "How does this summary look?",
      "options": [
        { "label": "Approve", "description": "Finalize and save to file" },
        {
          "label": "Regenerate",
          "description": "Start the draft over with different framing"
        }
      ]
    }
  ]
}
```

The Question tool's custom answer option allows the user to type edit instructions (e.g., "make the rec-gov section more detailed", "combine items 2 and 3", "change the tone to be more casual"). If the user types custom instructions, revise the draft and re-present for approval.

Repeat until the user approves.

#### On approval

1. Write the final summary to a temp file:
   ```bash
   tmpfile=$(mktemp "${TMPDIR:-/tmp}/work-summary-XXXXXX.md")
   ```
2. Print the full markdown in the chat so the user can see and copy it directly
3. Tell the user the file path

## Rules

- **Only the user's work.** Every query must be filtered by the user's identity — git author, GitHub username, Linear assignee. Never include commits, PRs, or issues authored by others. If a data source cannot be reliably filtered, note this and let the user deselect in Step 5.
- **Truthful and verifiable.** Every item in the summary must trace back to a concrete commit, PR, issue, or session. No fabrication, no embellishment. If something sounds impressive, it must be because the work was genuinely impressive.
- **No overselling.** Scale the language to the actual scope. A config tweak is a config tweak. A multi-week feature is a multi-week feature. The reader should be able to look at the PR diff and think "yes, that's an accurate description", not "that's a stretch."
- **Dedup aggressively.** A PR and its underlying commits are one unit of work, not twelve separate items. A Linear issue and the PR that closes it are one item. The summary should have roughly as many bullets as there were distinct pieces of work, not as many as there were commits.
- **Never post or share automatically.** The output is for the user to copy, paste, and share as they see fit. Never post to Slack, Linear, GitHub, or any external service.
- **Interactivity at every gate.** Time period selection (Step 1), repo selection (Step 2), item selection (Step 5), and draft review (Step 7) all require user input. Never skip a gate.
- **Graceful degradation.** If a data source is unavailable (no Linear CLI, no GitHub auth, empty database), skip it and note what was skipped. The skill should still produce useful output from whatever sources are available.
- **No noise in the output.** The final summary should not mention the data-gathering process, which sources were queried, or how deduplication was done. It should read as a clean changelog authored by a human.
- **Respect the user's edits.** If the user modifies the draft in Step 7, apply their changes faithfully. Do not re-edit their words or revert their tone choices.

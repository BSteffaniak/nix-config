# PR Description Shared Instructions

## Gathering Branch Changes

1. Get the current branch name: `git branch --show-current`
2. Determine branch-only commits using `git cherry -v` with fallbacks:
   - Try `master`, then `origin/master`, then `main`, then `origin/main`
   - This ensures only commits unique to the branch are considered — NOT commits from the base branch
3. Get diff stats: `git diff --stat <base>..HEAD` (exclude binary assets with `:!*.svg :!*.webp :!*.png :!*.jpg`)
4. Get the full diff: `git diff <base>..HEAD` (excluding binary assets)
   - For large diffs, focus on specific directories or use `--stat` to identify key areas first
5. If there are no branch-only commits, inform the user

## PR Description Format

Output as markdown with this structure:

### Title Line

- Format: `# <type>: <concise descriptive title>`
- Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`
- Specific to what the branch actually does

### Summary Section

- `## Summary`
- 1-3 sentences describing the high-level change
- Should read like an elevator pitch for the PR

### What Changed Section

- `## What Changed`
- Group changes by logical area, each with a `### Heading`
- Bullet points describing specific, concrete changes
- Name actual files, functions, constants, config keys, endpoints touched
- Multiple logical changes get their own subsection

## Strictly Forbidden

- "Files Touched" sections, line counts, or file lists — GitHub already shows this
- Anything that duplicates what the PR diff view shows (raw file names, addition/deletion counts)
- Including changes that are NOT unique to this branch (from the base branch)
- Generic descriptions — be specific about what was actually changed
- Motivation/reasoning paragraphs — the PR description is the WHAT, conversation/comments are the WHY

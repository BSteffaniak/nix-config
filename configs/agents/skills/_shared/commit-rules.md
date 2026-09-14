# Commit Message Shared Instructions

## Gathering Changes

1. Determine what changed:
   - Run `git diff --cached --stat` to check for staged changes
   - If there are staged changes, use `git diff --cached` for the full diff
   - If nothing is staged, use `git diff` for unstaged changes instead
   - If both are empty, inform the user there is nothing to commit
2. Optionally run `git log --oneline -10` to see recent commit style for context
3. Analyze the diff carefully — understand the specific, concrete changes

## Commit Message Rules

### Title

- Imperative mood ("Add", "Fix", "Remove", "Update", "Refactor", not "Added", "Fixes", "Removed")
- ~50 characters, 72 max
- No period at the end
- Specific to WHAT changed — name the actual thing (function, module, endpoint, component, file)

### Description

- Separate title and description with exactly one newline; do not insert a blank separator line.
- Do not hard-wrap the description or enforce any character-based line length limit. Use newlines only for intentional structure, such as separate bullets or paragraph breaks.
- Bullet points or short paragraph
- Describe WHAT the changes are, not WHY
- Keep each bullet concise. Name the thing changed, don't narrate every identifier touched.
- Aim for 3–8 bullets for typical changes, up to ~15 for large refactors. If you need more, the commit is probably too big — but write fewer, broader bullets rather than padding.
- Group related edits into one bullet — don't split "add X" and "wire X into Y" into two bullets unless the wiring is itself substantive.
- Skim test: a reviewer should grasp the commit in <10 seconds of scanning. If your message doesn't pass that, it's too long.
- Be specific about the thing that changed (module, function, config key, endpoint) — but resist listing every file, import swap, or mechanical rename unless that IS the change.

### Strictly Forbidden

- Generic messages: "Update code", "Fix bugs", "Code review changes", "Address feedback", "Make improvements", "Various updates", "Clean up"
- Overly detailed bullets. Split distinct changes or cut unnecessary detail instead; do not judge bullet length by wrapped lines.
- Exhaustive identifier dumps: listing every renamed import, every test fixture tweak, every type path swap. Describe the semantic change once.
- Describing motivation or reasoning — the commit message is the WHAT, the PR description is the WHY
- Repeating the title in the description
- Meaningless filler like "This commit..." or "Changes include..."

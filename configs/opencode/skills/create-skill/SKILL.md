---
name: create-skill
description: Create a new OpenCode skill. Interactive — gathers requirements, selects structural patterns, drafts the SKILL.md, and writes the files to the correct location.
allowed-tools: Bash(git:*), Bash(find:*), Bash(ls:*), Question(*), Write(*)
---

## Purpose

Create a new OpenCode skill by gathering requirements, selecting the appropriate structural pattern from established conventions, drafting the SKILL.md content, and writing the files to the correct location in the nix config repo. This skill encodes all the patterns and conventions used across existing skills so that new skills are consistent, well-structured, and correctly deployed.

## Repo Structure

Skills are managed as part of a nix configuration repo and deployed to `~/.config/opencode/skills/` via home-manager's `xdg.configFile`. Understanding this deployment model is critical:

- **Source of truth**: `configs/opencode/skills/<skill-name>/SKILL.md` in the nix config repo
- **Deployed to**: `~/.config/opencode/skills/<skill-name>/SKILL.md` by nix (via `xdg.configFile`)
- **Auto-discovered**: The nix module scans `configs/opencode/skills/` and deploys every directory it finds. Creating a new skill directory is sufficient — no nix config edits are needed.
- **NEVER create files directly in `~/.config/opencode/skills/`** — that directory is managed by nix and will be overwritten on rebuild.

### Finding the repo root

The nix config repo is the one containing the `configs/opencode/skills/` directory. Locate it:

```bash
git rev-parse --show-toplevel
```

Then verify the skills directory exists:

```bash
ls configs/opencode/skills/
```

If the current working directory is not inside the nix config repo, search for it by checking common locations or ask the user for the path.

### The `_shared/` directory

`configs/opencode/skills/_shared/` contains reference documents shared across **multiple** skill files. Examples:

- `commit-rules.md` — Used by `commit-message`, `commit-message-write`, `commit-message-staged`, `commit-message-staged-write`
- `code-comment-format.md` — Used by `pr-review` and `pr-annotate`
- `pr-description-rules.md` — Used by `pr-description` and `pr-description-write`

**Only add content to `_shared/` when it is genuinely referenced by 2 or more skill files.** Do not put single-skill content there. If a skill has internal reference material that only it uses, put it inline in the SKILL.md or in a subdirectory of the skill itself (e.g., `configs/opencode/skills/<name>/references/`).

## SKILL.md Conventions

### Frontmatter

Every SKILL.md starts with YAML frontmatter:

```yaml
---
name: <kebab-case-name>
description: <one sentence>
allowed-tools: <comma-separated tool list>
---
```

**`name`**: kebab-case, must match the directory name exactly.

**`description`**: One concise sentence. Patterns by skill type:

- Read-only: `"<verb> a <thing>. Read-only — prints the <output> for you to copy."`
- Write: `"<verb> a <thing> and write it to <destination>."`
- Interactive: `"<verb> <thing>. Interactive — <brief description of the workflow>."`
- General: `"<verb> <thing> <brief context>."`

**`allowed-tools`**: The **minimal** set of tools the skill actually needs. Only include tools the skill's instructions explicitly use. Common sets:

| Use case                     | allowed-tools                                                          |
| ---------------------------- | ---------------------------------------------------------------------- |
| Git operations only          | `Bash(git:*)`                                                          |
| Git + file writing           | `Bash(git:*), Write(*)`                                                |
| GitHub integration           | `Bash(git:*), Bash(gh:*), Bash(jq:*)`                                  |
| Interactive GitHub workflow  | `Bash(git:*), Bash(gh:*), Bash(jq:*), Question(*)`                     |
| Cross-platform scripting     | `Bash(python3:*)`                                                      |
| Multi-source data gathering  | `Bash(git:*), Bash(gh:*), Bash(linear:*), Bash(python3:*), Bash(jq:*)` |
| File creation                | `Write(*)`                                                             |
| Interactive with file output | `Question(*), Write(*), Bash(mktemp:*)`                                |

### Document structure

A SKILL.md follows this structure:

1. **Frontmatter** — name, description, allowed-tools
2. **Purpose** — One paragraph. What the skill does and why. Concrete, no fluff.
3. **Prerequisites** (optional) — Tools that must be installed, auth that must be configured. Only if the skill depends on something non-obvious.
4. **Steps** — Numbered steps (`### 1. Step name`). Sub-steps use `####`. Each step should be self-contained and describe exactly what to do, including example commands and expected output formats.
5. **Rules** — Bulleted list at the end. Bold rule name, dash, explanation. Mandatory for every skill. Rules are constraints and invariants that apply across all steps.

### Code examples

- Always use fenced code blocks with the correct language identifier
- Use realistic examples, not pseudocode — real commands with real flags
- Show expected output format when it's not obvious
- For bash commands, show the actual command that should be run
- For GraphQL queries, show the full query structure

### Rules section

Every skill must end with a `## Rules` section. Each rule is:

```markdown
- **Rule name.** Explanation of the constraint and why it matters.
```

Common rules that apply to most skills:

- **User confirmation before mutations** — Never write files, post comments, or make external API calls without explicit user approval
- **Truthful output** — Never fabricate or embellish information
- **Respect user edits** — If the user modifies content, preserve their changes faithfully

## Structural Patterns

When designing a new skill, select the pattern that best fits the use case. These patterns are drawn from existing skills.

### Pattern 1: Simple read-only

**Used by**: `commit-message`, `commit-message-staged`, `pr-description`

**When to use**: The skill generates text output for the user to copy. No files written, no external mutations, no interaction needed.

**Structure**:

- Purpose section
- Steps: gather input data → analyze → output formatted text
- Rules: minimal set

**Characteristics**:

- `allowed-tools` is narrow (often just `Bash(git:*)`)
- No `Question(*)` or `Write(*)` needed
- Steps are short and linear — no gates or loops
- Often references `_shared/` rules for formatting conventions

### Pattern 2: Simple write

**Used by**: `commit-message-write`, `commit-message-staged-write`, `pr-description-write`

**When to use**: Same as read-only but the output is written to a file (temp file, git dir, etc.) instead of just printed.

**Structure**: Same as read-only, plus a write step and a confirmation message telling the user where the file was written.

**Characteristics**:

- Adds `Write(*)` or `Bash(mktemp:*)` to allowed-tools
- The extra step is just "write to file + tell the user the path"
- Everything else is identical to the read-only variant

### Pattern 3: Read/write pair

**Used by**: `commit-message` + `commit-message-write`, `pr-description` + `pr-description-write`

**When to use**: The same core logic should exist in both "print for copying" and "write to file" forms. Users pick whichever suits their workflow.

**Structure**: Two separate SKILL.md files that both reference shared rules in `_shared/`. The read-only variant just prints; the write variant adds a file-writing step.

**Characteristics**:

- Shared logic goes in `_shared/<name>-rules.md` with anchored headings for referencing specific sections
- Each SKILL.md is small — it says "follow the shared steps, then do X"
- The `_shared/` doc contains: gathering input, analysis rules, formatting rules
- This is the **only** pattern where `_shared/` content should be created for a new skill

### Pattern 4: Interactive with gates

**Used by**: `pr-review`, `pr-annotate`, `work-summary`

**When to use**: The skill has a multi-step workflow where the user should control progression — selecting what to include, reviewing output, approving actions.

**Structure**:

- Multiple numbered steps with clear boundaries
- **Gates** between steps: the skill pauses and asks the user to confirm, select, or decide before proceeding
- The Question tool is used at each gate

**Gate patterns** (use the Question tool):

- **Multi-select filter**: Present discovered items, let user deselect what they don't want. Use `multiple: true`. All items pre-selected by default.

  ```json
  {
    "header": "Select items",
    "question": "Which items should I include?",
    "multiple": true,
    "options": [...]
  }
  ```

- **Single-choice action**: Ask the user what to do next.
  ```json
  {
    "header": "Action",
    "question": "How should I proceed?",
    "options": [
      { "label": "Approve", "description": "..." },
      { "label": "Skip", "description": "..." }
    ]
  }
  ```

**Characteristics**:

- `allowed-tools` includes `Question(*)`
- Steps are clearly numbered with ### headings
- Each gate is explicitly documented: what Question to ask, what options to show, how to handle each response
- The Rules section includes "Never skip a gate" and "Never act without user confirmation"

### Pattern 5: Per-item review loop

**Used by**: `pr-review` (Step 7), `pr-annotate` (Step 4), `work-summary` (Step 6)

**When to use**: The skill produces multiple items (comments, annotations, changelog lines) that the user should review and approve individually.

**Structure**: A loop within a step that processes one item at a time:

1. **Draft** the item
2. **Present** it with context
3. **Ask** via Question tool: Approve / Regenerate / Skip (+ custom text via built-in custom answer)
4. Handle response:
   - **Approve** → keep the item, move to next
   - **Regenerate** → redraft with different wording, re-present (loop back to 3)
   - **Skip** → drop the item, move to next
   - **Custom text** → apply edits, re-present (loop back to 3)
5. **Repeat** for all items

**Characteristics**:

- Regenerate and custom text loop back — they don't advance to the next item
- Only Approve and Skip advance the loop
- The Question tool's built-in custom answer option handles user-provided edits — no need for a separate "Edit" option
- After all items are processed, show a summary of what was approved and what was skipped
- Rules include "Process items one at a time — never batch"

### Pattern 6: Multi-source data gathering

**Used by**: `work-summary`

**When to use**: The skill collects data from multiple sources (git, GitHub, Linear, databases), deduplicates, and synthesizes output.

**Structure**:

- Identity resolution step (determine who the user is across sources)
- Discovery step (find what to scan)
- Parallel data gathering from each source
- Deduplication and merging
- Presentation for user curation

**Characteristics**:

- `allowed-tools` includes multiple Bash scopes for different tools
- **Graceful degradation** is essential: if a source is unavailable, skip it and note what was skipped
- **Cross-platform**: use `python3` for date math and SQLite queries — not platform-specific `date` flags (macOS `-v` vs GNU `-d`)
- **No hardcoded paths**: derive scan targets dynamically from available data (session history, current working directory), never hardcode user-specific directory paths
- Identity filtering on every query to ensure only the user's own data appears

## Steps

### 1. Gather requirements

If the user provides a description of the skill they want as an argument, parse it for as much information as possible. Then use the **Question tool** to fill in any gaps.

Ask the following, skipping any that can be inferred from the user's description:

```json
{
  "questions": [
    {
      "header": "Skill type",
      "question": "What pattern best fits this skill?",
      "options": [
        {
          "label": "Simple read-only",
          "description": "Generate text output for the user to copy"
        },
        {
          "label": "Simple write",
          "description": "Generate output and write it to a file"
        },
        {
          "label": "Read/write pair",
          "description": "Both a read-only and a write variant sharing common rules"
        },
        {
          "label": "Interactive",
          "description": "Multi-step workflow with user-controlled gates"
        },
        {
          "label": "Interactive + per-item",
          "description": "Interactive workflow that also reviews items one-by-one"
        }
      ]
    }
  ]
}
```

```json
{
  "questions": [
    {
      "header": "Tools needed",
      "question": "What tools and services does this skill need?",
      "multiple": true,
      "options": [
        {
          "label": "git",
          "description": "Git operations (log, diff, status, etc.)"
        },
        {
          "label": "gh",
          "description": "GitHub CLI (PRs, issues, GraphQL API)"
        },
        { "label": "linear", "description": "Linear CLI (issues, projects)" },
        {
          "label": "python3",
          "description": "Cross-platform scripting, SQLite, date math"
        },
        { "label": "jq", "description": "JSON processing" },
        {
          "label": "File writing",
          "description": "Write/mktemp for creating output files"
        }
      ]
    }
  ]
}
```

Based on the answers, determine:

- The skill name (kebab-case)
- The structural pattern to use
- The `allowed-tools` set
- Whether `_shared/` content is needed (only for read/write pairs or when genuinely sharing with existing skills)
- The high-level step outline

### 2. Design the skill

Based on the gathered requirements and the selected structural pattern, compose a design outline:

```
## Design: <skill-name>

**Pattern**: <pattern name>
**allowed-tools**: <tool list>
**Shared resources**: <none / _shared/<name>.md>

### Steps outline
1. <step name> — <brief description> [gate: <type>]
2. <step name> — <brief description>
3. <step name> — <brief description> [gate: <type>]
...

### Key rules
- <rule 1>
- <rule 2>
```

Present this to the user for approval using the **Question tool**:

```json
{
  "questions": [
    {
      "header": "Skill design",
      "question": "Does this design look right?",
      "options": [
        {
          "label": "Approve",
          "description": "Proceed to drafting the SKILL.md"
        },
        {
          "label": "Regenerate",
          "description": "Redesign with a different approach"
        }
      ]
    }
  ]
}
```

Handle the response:

- **Approve** — proceed to Step 3
- **Regenerate** — redesign and re-present
- **Custom text** — adjust the design per the user's instructions and re-present

### 3. Draft and review the SKILL.md

Draft the full SKILL.md content. Present it to the user **section by section** for review, using the per-item review loop pattern.

The sections to review individually are:

1. **Frontmatter** — name, description, allowed-tools
2. **Purpose** — the purpose paragraph
3. **Each step** — present each numbered step as a separate review item
4. **Rules** — the rules section

For each section, present the draft and use the **Question tool**:

```json
{
  "questions": [
    {
      "header": "Section: <name>",
      "question": "How does this section look?",
      "options": [
        {
          "label": "Approve",
          "description": "Keep this section and move to the next"
        },
        { "label": "Regenerate", "description": "Redraft this section" },
        { "label": "Skip", "description": "Remove this section entirely" }
      ]
    }
  ]
}
```

- **Approve** — keep, move to next section
- **Regenerate** — redraft with different wording/structure, re-present
- **Skip** — remove the section (only valid for optional sections, not frontmatter/purpose/rules)
- **Custom text** — apply edits, re-present

### 4. Create shared resources (if applicable)

If the skill design calls for `_shared/` content (read/write pairs, or sharing rules with existing skills):

1. Draft the shared document
2. Present it for review (same approve/regenerate/custom pattern)
3. Verify it is actually referenced by 2+ skill files — if not, move the content inline into the SKILL.md instead

If the skill design calls for a read/write pair, draft the second variant's SKILL.md and present it for review as well.

**Skip this step entirely if no shared resources are needed.**

### 5. Write files

After all content is approved, write the files:

1. Locate the nix config repo root:

   ```bash
   git rev-parse --show-toplevel
   ```

2. Verify the target directory doesn't already exist:

   ```bash
   ls configs/opencode/skills/<skill-name>/ 2>/dev/null
   ```

   If it exists, warn the user and ask whether to overwrite.

3. Write the SKILL.md:
   - Path: `<repo-root>/configs/opencode/skills/<skill-name>/SKILL.md`

4. Write any shared resources:
   - Path: `<repo-root>/configs/opencode/skills/_shared/<name>.md`

5. Write any additional variant SKILL.md files:
   - Path: `<repo-root>/configs/opencode/skills/<variant-name>/SKILL.md`

6. Confirm creation:

   ```
   Created:
   - configs/opencode/skills/<skill-name>/SKILL.md

   The skill will be auto-discovered and deployed on next nix rebuild.
   No other files need editing.
   ```

### 6. Review

Present the final file content(s) for a last look. Use the **Question tool**:

```json
{
  "questions": [
    {
      "header": "Final review",
      "question": "Everything look good?",
      "options": [
        { "label": "Done", "description": "All files are written and correct" }
      ]
    }
  ]
}
```

If the user provides custom text, apply the edits to the already-written files.

## Rules

- **Never create files in `~/.config/opencode/skills/`.** That directory is managed by nix. Always write to `configs/opencode/skills/` in the nix config repo.
- **No nix config edits needed.** Skills are auto-discovered from `configs/opencode/skills/`. Creating the directory and SKILL.md is sufficient.
- **Only add to `_shared/` when genuinely shared.** Content must be referenced by 2 or more skill files. Single-skill reference material goes inline in the SKILL.md or in a subdirectory of the skill itself.
- **`allowed-tools` must be minimal.** Only include tools the skill's instructions explicitly use. Over-permissioning is a security concern.
- **Cross-platform by default.** Use `python3` for date math, SQLite, and scripting. Never use macOS-only (`date -v`) or GNU-only (`date -d`) commands without a cross-platform alternative.
- **No hardcoded user-specific paths.** Derive directories dynamically from git, session history, or user input. Never embed paths like `~/GitHub` or `~/Projects`.
- **Every interactive skill needs gate rules.** If the skill uses the Question tool, its Rules section must include "Never act without user confirmation" and "Never skip a gate."
- **Per-item review means one at a time.** If the skill uses the per-item review loop pattern, its Rules section must enforce processing items individually — never batch.
- **Present before writing.** Never write files without the user having reviewed the content first. The draft-and-review cycle in Step 3 is mandatory.
- **Respect the user's edits.** If the user provides custom text or edit instructions at any point, apply their changes faithfully. Do not re-edit their words.
- **Skill names are kebab-case.** The name in frontmatter must match the directory name exactly. Use descriptive but concise names.

---
name: local-progress-doc
description: Create a local long-lived markdown progress document for cross-session task tracking. Interactive — gathers scope, drafts a practical checklist, and writes the approved file locally.
allowed-tools: Question(*), Read(*), Write(*)
---

## Purpose

Create a local, long-lived markdown progress document that captures the practical context, checklist, decisions, blockers, and handoff notes for a task that may span many agent sessions. Use this when the user wants durable working state that should stay local and generally should not be committed, so future sessions can resume from the document instead of reconstructing progress from chat history.

## Steps

### 1. Gather the task scope

Capture the user's task description and determine what the progress document should track. If any of these are missing, ask concise clarifying questions with the Question tool:

- The overall goal or outcome.
- The project, feature, migration, investigation, or system being worked on.
- The desired filename or a short slug to derive one from.
- Whether this is a new progress document or an update to an existing one.
- Any known constraints, non-goals, risks, or definitions of "done".

Use a concise question when helpful:

```json
{
  "questions": [
    {
      "questionTopic": "Progress document scope",
      "prompt": "What should this progress document track?",
      "type": "single",
      "options": [
        {
          "value": "use-description",
          "label": "Use current description",
          "description": "Draft from the task description already provided.",
          "recommended": true
        },
        {
          "value": "ask-more",
          "label": "Ask for more detail",
          "description": "Gather more context before drafting."
        }
      ]
    }
  ]
}
```

If the user already provided enough detail, summarize the inferred scope and continue without asking redundant questions.

### 2. Choose a local-only file path

Choose a practical markdown path for the document. Prefer a filename that is easy to recognize as local working state, such as:

- `<task-slug>-progress.md`
- `<task-slug>-handoff.md`
- `local-<task-slug>-progress.md`

If the user provides a path, use it. Otherwise, propose a path in the current working directory using a kebab-case task slug. Do not use git commands to verify ignore status. Instead, explicitly tell the user the file is intended to remain local and should not be staged or committed.

Before writing, include the proposed path in the outline approval gate.

### 3. Inspect available context for complex documents

For complex migrations, architecture plans, or updates to existing progress documents, read relevant local context before drafting when available:

- the existing progress document, if updating
- project instructions such as `AGENTS.md`
- obvious project docs/manifests such as `README.md`, `Cargo.toml`, package manifests, or plugin manifests
- user-provided files or paths

Use this evidence to resolve decisions up front when practical. Avoid leaving generic "investigate" checklist items if a quick read can answer the question now. If deeper research is not practical, make the remaining item concrete: name what to inspect and what decision or implementation step it should unblock.

### 4. Draft the progress document

Draft a markdown document that future sessions can use as durable working memory. Keep it high-level and practical: checklist items should represent meaningful workstreams or verifiable outcomes, not tiny mechanical steps.

For implementation or migration plans, checklist items must be actionable and verifiable. Prefer items that name the affected area and intended outcome.

Avoid vague items such as:

- "Investigate runtime behavior"
- "Think about compatibility"
- "Improve architecture"

Prefer concrete items such as:

- "Inspect `packages/plugin/src/loader.rs` process invocation paths and document how cancellation frames will be routed."
- "Add tests proving duplicate contribution IDs are rejected in the canonical registry."
- "Convert Bcode `tui_surfaces` manifest data into app-owned extension payloads."

For large multi-phase plans, structure each phase with:

- a short goal
- implementation checklist
- exit criteria
- validation notes when relevant

Avoid checklist-only plans when sequencing, compatibility, or migration risk matters.

For architecture or migration docs, separate locked decisions from open questions. If the user can decide an item now, ask and record the decision instead of leaving it as an ambiguous blocker.

Use this structure unless the user's task calls for a simpler document:

```markdown
# <Task title> Progress

## Purpose

<One short paragraph describing what this document tracks and why it exists.>

## Current status

- **State:** Not started | In progress | Blocked | Ready for review | Done
- **Last updated:** <YYYY-MM-DD or "update when edited">
- **Owner/session:** Local working notes

## Definition of done

- [ ] <High-level outcome that means the task is complete>
- [ ] <Another completion criterion>

## Scope

### In scope

- <Included area>

### Out of scope / non-goals

- <Excluded area or "None noted yet">

## Locked decisions

- <YYYY-MM-DD> — <Decision and rationale>

## Practical checklist

### <Workstream 1>

- [ ] <High-level practical task>
- [ ] <High-level practical task>

### <Workstream 2>

- [ ] <High-level practical task>
- [ ] <High-level practical task>

## Decisions

- <YYYY-MM-DD> — <New decision made while executing the plan>

## Blockers and questions

- [ ] <Open question, blocker, or dependency>

## Session handoff notes

- <Most important context for the next session>
- <Where to resume>

## Update rules for future sessions

- Read this file before starting related work.
- Update checkboxes as work is completed.
- Add decisions with dates and short rationale.
- Add blockers/questions instead of losing them in chat.
- Keep this file local unless the user explicitly decides to commit it.
```

If updating an existing progress document, read it first and preserve its existing structure and user edits. Preserve completed checkboxes, locked decisions, user wording, current phase structure, and handoff notes. Add missing sections only when useful, and never reset completed checkboxes or rewrite structure unless the user explicitly asks.

### 5. Get approval before writing

Present a concise outline before creating or overwriting any file. Include:

- The proposed path.
- The inferred task goal.
- The document sections.
- A preview of the high-level checklist.

Before asking for approval on complex documents, do a brief ambiguity review:

- Are any checklist items vague or non-actionable?
- Are any "research" tasks answerable from available context now?
- Are decisions, non-goals, blockers, and validation separated clearly?
- Do later phases reflect earlier locked decisions?

Ask for approval with the Question tool:

```json
{
  "questions": [
    {
      "questionTopic": "Progress document approval",
      "prompt": "Create this local progress document?",
      "type": "single",
      "options": [
        {
          "value": "approve",
          "label": "Create",
          "description": "Write the markdown file at the proposed path.",
          "recommended": true
        },
        {
          "value": "revise",
          "label": "Revise",
          "description": "Adjust the outline before writing."
        },
        {
          "value": "cancel",
          "label": "Cancel",
          "description": "Do not write a file."
        }
      ]
    }
  ]
}
```

Handle the response:

- **Create** — write the file exactly as approved.
- **Revise** — apply the user's requested changes and present the updated outline again.
- **Cancel** — stop without writing.
- **Custom text** — apply the requested edits and present the updated outline again.

### 6. Write the file and report next steps

After the user approves the exact document content and path, write the markdown file with the Write tool. If the target file already exists, do not overwrite it silently; ask whether to update, replace, or choose a different path.

After writing, report:

- The file path.
- That it is intended as local working state.
- That the user should avoid staging or committing it unless they explicitly decide otherwise.
- How to use it in future sessions, for example: "Read `<path>` and continue from the session handoff notes, updating checkboxes and decisions as you work."

### 7. Maintain the document in later sessions

When the user asks to continue work using an existing progress document:

1. Read the file before planning or making changes.
2. Treat checked boxes, decisions, and handoff notes as current working context.
3. Update checkboxes as meaningful outcomes are completed.
4. Add new decisions, blockers, and handoff notes as the work evolves.
5. Preserve the user's wording and structure unless they ask for cleanup.
6. Keep updates high-level enough that the document remains useful across many sessions.

## Rules

- **Never write without approval.** Present the path, outline, and checklist preview before creating or overwriting a file.
- **Never skip a gate.** If the workflow reaches an approval point, wait for a direct user response before continuing.
- **Local working state only.** Treat the document as long-lived local task memory, not committed project documentation, unless the user explicitly says otherwise.
- **Warn about staging.** Remind the user that the file should generally not be staged or committed.
- **Actionable implementation plans.** For implementation or migration documents, checklist items should name affected areas and verifiable outcomes. Avoid vague investigation-only items when available context can answer the question now.
- **Preserve existing progress.** When updating an existing document, read it first and keep completed checkboxes, locked decisions, phase structure, handoff notes, and user edits intact unless the user explicitly asks to change them.
- **Respect user edits.** If the user supplies custom wording, paths, sections, or checklist items, preserve them faithfully.
- **No hidden repository mutations.** Do not edit ignore files, stage files, commit changes, or run repository commands as part of this skill.
- **Non-interactive fallback.** If interactive questions are unavailable, draft the outline and ask the user to approve it in chat before writing.

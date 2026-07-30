---
name: resume-progress-doc
description: Reconstruct the current context of a paused effort from its progress document and codebase. Read-only — verifies documented state, gathers relevant knowledge, and stops without recommending or starting work.
allowed-tools: Bash(git:*), Glob(*), Grep(*), Read(*)
---

## Command execution

Follow the [non-interactive Git command rules](../_shared/non-interactive-git.md) for every `git` invocation.

Git access in this skill is strictly read-only. Never stage, commit, restore, reset, checkout, switch, clean, stash, or otherwise mutate repository state.

## Purpose

Reconstruct the current context of a paused multi-session effort by comparing its local progress document with the repository as it exists now. Gather enough accurate knowledge for the user or a later workflow to understand the objective, implementation state, remaining documented work, decisions, constraints, blockers, and validation history without relying on stale session memory.

The governing principle is:

> Reconstruct current context accurately, then stop.

This skill is for knowledge gathering only. It does not rewrite the progress document, modify code, run validation, recommend a next task, reorder the plan, ask how to continue, or begin implementation.

Use `local-progress-doc` to create a progress document. Use `refocus-progress-doc` when the goal is to rewrite or simplify one.

## Steps

### 1. Resolve the progress document

Use a path supplied by the user when available. Otherwise, search narrowly for likely local working documents:

- `*progress*.md`
- `*handoff*.md`
- `local-*.md`

Exclude generated, dependency, cache, and VCS directories. Do not perform an unbounded filesystem search.

If exactly one strong candidate exists, use it and state the selected path. If multiple plausible candidates exist, list them with enough context for the user to choose and stop. Do not ask a question or infer solely from modification time.

If no plausible document exists, report that no progress document could be resolved and stop.

Read the selected document in full before drawing conclusions.

### 2. Recover the documented context

Extract the document's working model:

- Overall objective and definition of done.
- Scope and non-goals.
- Completed outcomes.
- Remaining checklist items in their documented order.
- Active decisions and their rationale.
- Constraints and dependencies.
- Blockers, risks, and unresolved questions.
- Validation requirements and recorded results.
- Handoff notes.
- Referenced files, modules, symbols, commands, issues, and commits.

Distinguish among:

1. **Documented intent** — what the effort is supposed to accomplish.
2. **Documented status** — what the progress document says has happened.
3. **Repository evidence** — what the current code and Git state support.
4. **Unresolved context** — claims or assumptions that available evidence cannot establish.

Do not treat checkbox state, confident wording, old handoff notes, or commit messages as conclusive proof.

### 3. Establish repository context

Read applicable repository instructions such as `AGENTS.md`. Treat those instructions as binding context and include relevant constraints in the final brief.

Inspect current Git state with non-interactive, read-only commands such as:

```bash
git --no-pager status --short --branch
git --no-pager log --oneline --decorate -n 20
git --no-pager diff --stat
git --no-pager diff --cached --stat
```

Use narrower history or diff commands when the document identifies relevant paths or commits:

```bash
git --no-pager log --oneline -- path/to/relevant-area
git --no-pager diff -- path/to/relevant-area
git --no-pager show --stat --oneline <commit>
```

Account for:

- Current branch and divergence.
- Uncommitted or staged work.
- Recent commits relevant to the documented effort.
- Whether the repository is mid-operation.
- User changes that affect the documented state.
- Repository architecture and workflow rules relevant to the effort.

Do not assume a clean worktree or default branch.

### 4. Inspect the relevant implementation

Start with paths, modules, symbols, tests, and concepts named by the progress document. Read enough surrounding implementation and configuration to understand how those areas fit together.

Expand the scope only when imports, call sites, module wiring, generated outputs, tests, or repository architecture show that adjacent areas are relevant.

For meaningful documented status claims, determine whether current evidence is:

- **Confirmed** — repository evidence supports the claim.
- **Partially confirmed** — some expected evidence exists, but the claim is incomplete or uncertain.
- **Contradicted** — current evidence conflicts with the document.
- **Obsolete** — later implementation or decisions appear to have superseded the claim.
- **Unverified** — read-only inspection cannot establish the claim.

Record concrete evidence using paths, symbols, configuration entries, tests, or commits. Keep the investigation proportional to reconstructing context; do not turn it into an exhaustive code review.

### 5. Reconcile document and repository knowledge

Build a neutral account of the effort's current state.

Identify:

- Completed outcomes supported by repository evidence.
- Documented completed outcomes that remain uncertain or contradicted.
- Remaining work that still appears consistent with the current codebase.
- Remaining items that appear complete, obsolete, or affected by later changes.
- Relevant implementation or constraints absent from the document.
- Decisions and assumptions that still shape the work.
- Blockers and unresolved questions without attempting to resolve them through user interaction.
- Validation commands required by the document or repository instructions.
- Recorded validation results, clearly labeled as historical.

Preserve the progress document's ordering and intent when reporting remaining work. Do not optimize, reprioritize, or choose what should happen next.

Do not run builds, tests, linters, formatters, or other validation commands. This skill reports validation knowledge; it does not establish new validation results.

### 6. Present the context brief

Present a concise report using the sections that contain useful information:

```markdown
# Current Context

## Progress Document

- Path: <selected path>
- Stated purpose: <brief summary>

## Objective and Scope

<Current intended outcome, definition of done, scope, and non-goals>

## Repository State

- Branch: <branch>
- Working tree: <clean or concise summary>
- Relevant recent changes: <summary>
- Applicable instructions: <important constraints>

## Relevant Architecture

- <Important modules, relationships, files, and symbols>

## Confirmed Progress

- <Completed outcome and supporting evidence>

## Remaining Documented Work

1. <Item in its documented order and its apparent current status>
2. <Item in its documented order and its apparent current status>

## Decisions and Constraints

- <Still-relevant decision, rationale, or constraint>

## Blockers and Unresolved Questions

- <Documented or discovered uncertainty>

## Document–Code Discrepancies

- <Document claim versus current repository evidence>

## Validation Context

- Required: `<documented or repository-required command>`
- Historical result: <recorded result and source, without claiming it is current>

## Context Summary

<Compact account of where the effort currently stands>
```

Omit empty sections rather than filling them with boilerplate. Clearly distinguish verified facts, reasonable inferences, document claims, and unresolved uncertainty.

End after the context brief. Do not add recommendations, next steps, readiness ratings, offers to continue, or questions.

## Rules

- **Read-only workflow.** Never edit the progress document, code, configuration, Git state, or external systems.
- **Knowledge gathering only.** Reconstruct and report context; do not plan, prioritize, recommend, validate, or execute work.
- **Current truth wins for status.** Current code, configuration, Git state, and binding repository instructions outrank stale status claims.
- **Documented intent remains intent.** Do not discard a requirement merely because its implementation is absent; distinguish desired work from current state.
- **Preserve documented order.** Report remaining work in its existing order rather than constructing an execution sequence.
- **Evidence over checkboxes.** A checked item, handoff note, or commit message is not sufficient evidence by itself.
- **Separate certainty levels.** Clearly distinguish verified facts, reasonable inferences, historical validation, document claims, and unresolved assumptions.
- **Do not run validation.** Report required commands and historical results without executing builds, tests, linters, formatters, or checks.
- **Do not fabricate validation.** Never present a documented past result as a current passing result.
- **Respect user changes.** Treat staged and unstaged work as intentional context unless evidence says otherwise.
- **Narrow before broad.** Start from areas named by the document and expand only when repository relationships require it.
- **No interaction loop.** Do not ask questions or present continuation choices. If required input is missing or ambiguous, report it and stop.
- **No action framing.** Do not select a restart point, recommend a next task, define an implementation plan, or suggest beginning work.
- **Local working state.** Treat the progress document as local-only unless the user explicitly states otherwise, and never stage or commit it.

---
name: resume-progress-doc
description: Reconstruct the current product, architecture, and implementation context of a paused effort from its progress document and codebase. Read-only — gathers evidence and stops without recommending or starting work.
allowed-tools: Bash(git:*), Glob(*), Grep(*), Read(*)
---

## Command execution

Follow the [non-interactive Git command rules](../_shared/non-interactive-git.md) for every `git` invocation.

Git access in this skill is strictly read-only. Never stage, commit, restore, reset, checkout, switch, clean, stash, or otherwise mutate repository state.

## Governing contract

Read [the progress-document product and architecture contract](../_shared/progress-doc-completion.md) as the vocabulary for evaluating product and architectural context. This skill reports how the current effort relates to that contract; it does not repair the plan or prescribe work.

## Purpose

Reconstruct the current context of a paused multi-session effort by comparing its local progress document with the repository as it exists now. Gather enough accurate knowledge to understand:

- The original requested product outcome.
- The intended entry point and observable result.
- The relevant product flow and repository architecture.
- Completed and remaining documented work.
- Product-closure and architectural-integrity status.
- Decisions, constraints, blockers, discrepancies, and validation history.

The governing principle is:

> Reconstruct current context accurately, then stop.

This skill is for knowledge gathering only. It does not rewrite the progress document, modify code, run validation, recommend a next task, reorder the plan, ask how to continue, or begin implementation.

Use `local-progress-doc` to create or initially plan a document. Use `refocus-progress-doc` when the goal is to repair, rewrite, or simplify one.

## Steps

### 1. Resolve the progress document

Use a path supplied by the user when available. Otherwise, search narrowly for likely local working documents:

- `*progress*.md`
- `*handoff*.md`
- `local-*.md`

Exclude generated, dependency, cache, and VCS directories. Do not perform an unbounded filesystem search.

If exactly one strong candidate exists, use it and state the path. If multiple plausible candidates exist, list them with enough context for the user to choose and stop. Do not ask a question or infer solely from modification time.

If no plausible document exists, report that no progress document could be resolved and stop.

Read the selected document in full before drawing conclusions.

### 2. Recover the documented context

Extract:

- Original requested capability, intended entry point, observable result, and boundaries when documented.
- Overall objective and definition of done.
- Completed outcomes.
- Remaining checklist items in their documented order.
- Documented completion path and architectural obligations.
- Active decisions and rationale.
- Constraints, dependencies, blockers, risks, and unresolved questions.
- Validation requirements and recorded results.
- Handoff notes.
- Referenced files, modules, symbols, commands, issues, and commits.

Distinguish among:

1. **Documented intent** — what the effort is supposed to accomplish.
2. **Documented status** — what the progress document says has happened.
3. **Repository evidence** — what current code and Git state support.
4. **Unresolved context** — what read-only inspection cannot establish.

Do not treat checkbox state, confident wording, old handoff notes, or commit messages as conclusive proof.

### 3. Establish repository context

Read applicable repository instructions and architecture documentation. Treat binding instructions as authoritative context.

Inspect current Git state with non-interactive, read-only commands such as:

```bash
git --no-pager status --short --branch
git --no-pager log --oneline --decorate -n 20
git --no-pager diff --stat
git --no-pager diff --cached --stat
```

Use narrower commands when the document identifies relevant paths or commits:

```bash
git --no-pager log --oneline -- path/to/relevant-area
git --no-pager diff -- path/to/relevant-area
git --no-pager show --stat --oneline <commit>
```

Account for:

- Current branch and divergence.
- Uncommitted or staged work.
- Relevant recent commits.
- Whether the repository is mid-operation.
- User changes affecting documented state.
- Relevant repository architecture and workflow rules.

Do not assume a clean worktree or default branch.

### 4. Research the relevant codebase context

Start with paths, modules, symbols, tests, and concepts named by the progress document. Read enough surrounding implementation to understand the real product and architecture context:

- Intended product entry point and existing wiring.
- Current end-to-end flow related to the requested capability.
- Owners of behavior, state, persistence, lifecycle, errors, and observable results where relevant.
- Canonical sources of truth and architectural boundaries.
- Analogous production implementations and established patterns.
- Relevant tests, configuration, packaging, migrations, compatibility behavior, and integration paths.
- Focused Git history when current code does not explain an important decision.

Expand only when imports, call sites, module wiring, ownership, data flow, or repository architecture show that adjacent areas matter. Research should be sufficient to reconstruct context, not become an exhaustive code review or a new implementation plan.

Architectural claims require concrete repository evidence such as instructions, paths, symbols, tests, analogous implementations, invariants, or commits. Label generic inference as inference rather than repository truth.

### 5. Reconstruct product and architecture status

When the document covers product-delivery work, reconstruct the evidenced canonical path:

```text
intended entry point
→ existing product wiring
→ owning architectural layers
→ requested behavior
→ observable useful result
```

Report whether each meaningful status claim is:

- **Confirmed** — current repository evidence supports it.
- **Partially confirmed** — some evidence exists, but the claimed outcome is incomplete or uncertain.
- **Contradicted** — current evidence conflicts with it.
- **Obsolete** — later implementation or decisions appear to supersede it.
- **Unverified** — read-only inspection cannot establish it.

Assess product closure factually:

- Whether the requested behavior exists.
- Whether it is reachable through the intended entry point.
- Whether required layers appear connected.
- Whether the observable result is represented by current code.
- Whether undocumented manual bridging or demonstration-only behavior appears to remain.

Assess architectural integrity factually:

- Whether current implementation follows documented repository boundaries, ownership, and canonical sources of truth.
- Whether evidence suggests a layer bypass, duplicate ownership, hardcoded special case, temporary wiring, or incomplete integration.
- Whether relevant lifecycle, persistence, migration, compatibility, error, cleanup, or operational obligations are represented.
- Whether architectural decisions are grounded in repository evidence or appear to be unsupported ideals.
- Whether the design appears to introduce speculative generalization beyond the request.

Do not automatically label a compatibility adapter or migration path as a shortcut. Report its purpose, fit, ownership, lifecycle, and documented completion/removal conditions when evidence exists.

These are context findings, not recommendations. Do not construct a corrected design or decide what should be implemented next.

### 6. Reconcile document and repository knowledge

Build a neutral account identifying:

- Completed outcomes supported by evidence.
- Completed claims that remain partial, contradicted, obsolete, or unverified.
- Remaining work still consistent with current code and product intent.
- Remaining items that appear complete, superseded, or affected by later changes.
- Product-path layers represented or missing from the document.
- Architectural obligations represented or missing from the document.
- Relevant implementation, constraints, or evidence absent from the document.
- Decisions and assumptions still shaping the work.
- Blockers and unresolved questions.
- Required validation commands and historical validation results.

Preserve the progress document's ordering when reporting remaining work. Do not optimize, reprioritize, select a restart point, or turn coverage gaps into a new plan.

Do not run builds, tests, linters, formatters, or other validation commands. Report validation knowledge only.

### 7. Present the context brief

Use the sections that contain useful information:

```markdown
# Current Context

## Progress Document

- Path: <selected path>
- Stated purpose: <brief summary>

## Requested Product Outcome

- **Capability:** <documented intent>
- **Intended entry point:** <documented or evidenced surface>
- **Observable result:** <documented result>
- **Boundaries / non-goals:** <documented limits>

## Repository State

- Branch: <branch>
- Working tree: <clean or concise summary>
- Relevant recent changes: <summary>
- Applicable instructions: <important constraints>

## Relevant Architecture

- **Current flow:** <evidenced flow>
- **Owners and boundaries:** <modules/layers>
- **Canonical source of truth:** <owner, not applicable, or unresolved>
- **Analogous patterns:** <evidence-backed context>

## Evidenced Completion Path

1. <Entry point through observable result, with known gaps labeled>

## Confirmed Progress

- <Outcome and evidence>

## Remaining Documented Work

1. <Item in documented order and its evidenced status>

## Product Closure Status

- <Confirmed, partial, contradicted, or unverified product-path facts>

## Architectural Integrity Status

- <Evidence about proper architecture, affected obligations, or suspected gaps>

## Decisions and Constraints

- <Still-relevant decision, rationale, or constraint>

## Blockers and Unresolved Questions

- <Documented or discovered uncertainty>

## Document–Code Discrepancies

- <Document claim versus current repository evidence>

## Progress-Document Coverage Gaps

- <Missing product outcome, completion-path, architecture, or validation context>

## Validation Context

- Required: `<documented or repository-required command>`
- Historical result: <recorded result and source, without claiming it is current>

## Context Summary

<Compact neutral account of where the effort currently stands>
```

Omit empty sections. Clearly distinguish verified facts, reasonable inferences, document claims, historical results, and unresolved uncertainty.

End after the context brief. Do not add recommendations, corrected checklist items, next steps, readiness ratings, offers to continue, or questions.

## Rules

- **Read-only workflow.** Never edit the progress document, code, configuration, Git state, or external systems.
- **Knowledge gathering only.** Reconstruct and report context; do not plan, prioritize, recommend, validate, or execute work.
- **Use the shared contract descriptively.** Report product and architecture status without turning the contract into a new plan.
- **Research repository reality.** Ground architecture context in actual code, instructions, patterns, and evidence—not generic ideals.
- **Current truth wins for status.** Current code, configuration, Git state, and binding instructions outrank stale status claims.
- **Documented intent remains intent.** Do not discard or expand requirements based solely on implementation state.
- **Preserve documented order.** Report remaining work in its existing order.
- **Evidence over checkboxes.** A checked item, handoff note, or commit message is not sufficient evidence by itself.
- **Separate certainty levels.** Distinguish verified facts, inferences, historical validation, document claims, and unresolved assumptions.
- **Do not run validation.** Report commands and historical results without executing checks.
- **Do not fabricate validation.** Never present a past result as current.
- **Do not misclassify transitions.** Evaluate compatibility and migration mechanisms in context rather than assuming every temporary-looking layer is a shortcut.
- **Respect user changes.** Treat staged and unstaged work as intentional context unless evidence says otherwise.
- **Narrow before broad.** Start from document references and expand only as repository relationships require.
- **No interaction loop.** Do not ask questions or present continuation choices. If required input is missing or ambiguous, report it and stop.
- **No action framing.** Do not select a restart point, recommend a task, correct the plan, or suggest beginning work.
- **Local working state.** Treat the progress document as local-only unless explicitly stated otherwise, and never stage or commit it.

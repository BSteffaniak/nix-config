---
name: resume-progress-doc
description: Reconcile a local progress document with the current codebase and prepare an execution-ready restart brief. Interactive — verifies current truth, orders remaining work, and identifies the best next task without modifying files.
allowed-tools: Bash(git:*), Glob(*), Grep(*), Read(*), Question(*)
---

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` invocation.

Git access in this skill is strictly read-only. Never stage, commit, restore, reset, checkout, switch, clean, stash, or otherwise mutate repository state.

## Purpose

Resume a paused multi-session effort by reconciling its local progress document with the current repository. Verify that completed work, remaining tasks, decisions, blockers, and validation notes still reflect the codebase, then produce a concrete restart brief centered on continuing execution. This skill does not rewrite the progress document, modify code, or begin implementation.

Use this after `local-progress-doc` has created durable working memory and work has paused long enough that the document may no longer represent current truth. Use `refocus-progress-doc` instead when the primary goal is to rewrite or simplify the document.

## Steps

### 1. Resolve the progress document

Use a path supplied by the user when available. Otherwise, search narrowly for likely local working documents:

- `*progress*.md`
- `*handoff*.md`
- `local-*.md`

Exclude generated, dependency, cache, and VCS directories. Do not perform an unbounded filesystem search.

If exactly one strong candidate exists, use it and state the selected path. If multiple plausible candidates exist, use the Question tool to ask the user which one to inspect. Do not infer solely from the newest modification time.

Read the selected document in full before drawing conclusions.

### 2. Recover the intended work

Extract the document's current working model:

- Overall objective and definition of done.
- Completed outcomes.
- Remaining checklist items and their apparent order.
- Active decisions and constraints.
- Blockers, risks, and unresolved questions.
- Validation requirements.
- Handoff notes and proposed restart point.
- Files, modules, commands, issues, or commits referenced by the document.

Separate these into:

1. **Claims to verify** — statements that should have repository evidence.
2. **Plan intent** — desired future behavior or scope.
3. **Unresolved assumptions** — statements that may affect execution but lack enough evidence.

Do not treat checkbox state, confident wording, or old handoff notes as proof.

### 3. Establish repository context

Read applicable repository instructions such as `AGENTS.md` before evaluating the plan. Treat those instructions as binding.

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
- User changes that must not be overwritten.
- Validation requirements imposed by repository instructions.

Do not assume a clean worktree or default branch.

### 4. Inspect the relevant implementation

Use references from the progress document to choose an initially narrow inspection scope. Read the implementation, tests, configuration, and documentation needed to evaluate its claims.

Expand the scope only when imports, call sites, module wiring, generated outputs, or repository architecture show that adjacent areas are relevant.

For each meaningful progress claim, classify it as:

- **Confirmed** — current repository evidence supports it.
- **Partially confirmed** — some expected implementation exists, but the outcome is incomplete or uncertain.
- **Contradicted** — current evidence conflicts with the document.
- **Obsolete** — later implementation or decisions make it no longer applicable.
- **Unverified** — available evidence is insufficient without running commands or asking the user.

Record concrete evidence using paths, symbols, tests, configuration entries, or commits. Do not claim that tests pass unless current evidence shows they were run successfully; documented past results are historical evidence only.

### 5. Reconcile the remaining plan

Review each remaining task against current code and the objective.

Determine whether it is:

- Already complete but not marked complete.
- Still actionable as written.
- Valid but underspecified.
- Blocked by a decision or prerequisite.
- Ordered incorrectly.
- Superseded or obsolete.
- Outside the current objective.

Reconstruct the remaining execution order from actual dependencies rather than preserving document order mechanically.

Ask the user a concise Question only when ambiguity genuinely blocks selecting a safe next task. Include the evidence and explain why repository inspection cannot resolve it. Do not ask about uncertainties that can be answered by reading more relevant code.

### 6. Select the restart point

Choose the smallest high-confidence next task that materially advances the objective.

The task must include:

- The outcome to achieve.
- Why it is next.
- Likely files or implementation areas.
- Dependencies or constraints.
- Completion evidence.
- Relevant validation commands.
- Any assumptions that must be checked while implementing.

Prefer an executable implementation or validation task over vague instructions such as “investigate,” “continue,” or “review code.” If investigation is unavoidable, define the exact question, evidence to gather, and decision it will unlock.

Do not begin the task within this skill.

### 7. Present the execution-readiness brief

Present a concise report using this structure:

```markdown
# Resume Brief

## Objective

<Current intended outcome and definition of done>

## Repository State

- Branch: <branch>
- Working tree: <clean or concise summary>
- Relevant recent changes: <summary>
- Applicable instructions: <important constraints>

## Confirmed Progress

- <Completed outcome and evidence>

## Discrepancies

- <Document claim versus current repository truth>
- <Impact on the remaining plan>

## Blockers and Open Decisions

- <Only issues that affect continued execution>
- None, if no blockers remain.

## Remaining Work

1. <Dependency-ordered task>
2. <Next task>

## Recommended Next Task

**Outcome:** <specific result>
**Why now:** <dependency or value>
**Likely scope:** <paths or components>
**Completion evidence:** <observable result>
**Validation:** `<command>`
**Assumptions:** <items to verify, or none>

## Readiness

<Ready / Ready with assumptions / Blocked>
<Brief explanation>
```

Keep the report focused on resuming execution. Do not turn it into a changelog, exhaustive code review, or rewritten progress document.

### 8. Ask how to continue

Use the Question tool after presenting the complete brief:

```json
{
  "questions": [
    {
      "header": "Continue",
      "question": "How would you like to proceed?",
      "options": [
        {
          "label": "Start the recommended task",
          "description": "Leave this read-only workflow and begin implementation."
        },
        {
          "label": "Inspect a discrepancy",
          "description": "Deepen the read-only investigation before implementation."
        },
        {
          "label": "Stop here",
          "description": "Keep the resume brief as the handoff."
        }
      ]
    }
  ]
}
```

If the user chooses implementation, clearly transition out of this skill before changing files. Normal coding-agent permissions and repository validation rules then apply.

If the user chooses a discrepancy, ask which one only when their selection is ambiguous, inspect it read-only, and present an updated brief.

## Rules

- **Read-only workflow.** Never edit the progress document, code, configuration, Git state, or external systems while this skill is active.
- **Prepare for execution.** Optimize the investigation and report for beginning useful work, not for preserving history or polishing prose.
- **Current truth wins.** Current code, tests, configuration, Git state, and binding repository instructions outrank stale document claims.
- **Preserve plan intent.** Do not discard a requirement merely because its implementation is absent; distinguish intended work from inaccurate status.
- **Evidence over checkboxes.** A checked item, handoff note, or commit message is not sufficient evidence by itself.
- **Separate certainty levels.** Clearly distinguish verified facts, reasonable inferences, historical validation, and unresolved assumptions.
- **Do not fabricate validation.** Never say a check passes unless current evidence supports that result.
- **Respect user changes.** Treat staged and unstaged work as intentional unless evidence or the user says otherwise.
- **Narrow before broad.** Start from paths and concepts named by the document, then expand only when repository relationships require it.
- **Executable next step.** Recommend a bounded task with scope, completion evidence, and validation rather than a vague instruction.
- **Do not start implementation.** End with the restart brief and continuation gate; implementation belongs to the next workflow.
- **Never skip a gate.** Resolve ambiguous document selection and the final continuation choice through direct user responses.
- **Never act without user confirmation.** Do not transition into implementation based on a recommendation, default, or inferred preference.
- **Non-interactive fallback.** If Question is unavailable, present the brief and ask in normal chat how the user wants to continue.
- **Local working state.** Treat the progress document as local-only unless the user explicitly states otherwise, and do not stage or commit it.

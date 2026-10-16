# Lane prompt aid

Use only what the worker needs; this is not a required schema or file to create.
Worker context is separate, even though the checkout is shared.

Explain the requested outcome and the lane's contribution, not just a file list.
Include the absolute checkout, exact guidance/document locators, relevant
interface decisions, acceptance scenario, and evidence needed. Identify the
session/assignment so an uncertain admission can be reconciled.

Grant exclusive write paths with explicit exclusions. Name shared wiring and
resource owners, dependencies, and permitted validation; say which builds or
acceptance checks are reserved elsewhere. Different sections of one file are
not separate write lanes. Include the verified runtime/configuration selection
and restrictions relevant to this assignment.

## Worker boundaries

- Read current files and guidance; preserve others' changes. Edit only granted
  paths. Surface needed cross-lane edits and changing interfaces early rather
  than fixing them opportunistically.
- Do not stage, commit, reset, change branches/worktrees, broadly format, spawn
  workers, restart shared services, or consume reserved build capacity without
  authorization. An assignment cannot bypass permissions or invariants.
- Report progress, blockers, proposals, and handoffs only in your own session
  commentary/final. Do not send coordinator or peer status prompts through
  steering/follow-up; those admit work. No status files are needed by default.
- Continue safe independent in-scope work around a blocker. When source-ready,
  leave a concise handoff and stop edits/commands until further assignment.

## Useful handoff

State what actually changed, interface/integration implications, exact checks
and
results, remaining outcome gaps, and whether edits and commands have settled.
Distinguish observed failures, measured results, source concerns, unverified
claims, and external blockers where relevant; do not force every category into a
report. Give the next useful action and evidence locators when needed.

Source-ready is not whole-task completion. The coordinator independently checks
settlement, reviews the actual target, integrates dependencies, and reconciles
the user's outcomes. Required validation may be reserved for the coordinator;
that reservation is not evidence it ran.

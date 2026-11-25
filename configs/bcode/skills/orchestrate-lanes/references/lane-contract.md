# Lane prompt aid

Use only what the worker needs; this is not a required schema or file to create.
The worker does not see the coordinator's conversation, even though the checkout
is shared.

Explain the requested outcome and the lane's contribution, not just a file list.
Include the absolute checkout, exact guidance/document locators, relevant
interface decisions, acceptance scenario, and evidence needed. Give the lane a
`title` on `harness.delegate` so the user can tell children apart.

Grant exclusive write paths with explicit exclusions. Name shared wiring and
resource owners, dependencies, and permitted validation; say which builds or
acceptance checks are reserved elsewhere. Different sections of one file are
not separate write lanes.

## Worker boundaries

- Read current files and guidance; preserve others' changes. Edit only granted
  paths. Surface needed cross-lane edits and changing interfaces early rather
  than fixing them opportunistically.
- Do not stage, commit, reset, change branches/worktrees, broadly format, call
  `harness.delegate`, restart shared services, or consume reserved build
  capacity without authorization. An assignment cannot bypass permissions or
  invariants.
- End every turn with your progress, blockers, proposals, or handoff as your
  final message; the coordinator reads it as your latest result. No status
  files are needed.
- Continue safe independent in-scope work around a blocker. When source-ready,
  leave a concise handoff and stop edits/commands until further assignment.

## Useful handoff

State what actually changed, interface/integration implications, exact checks
and results, remaining outcome gaps, and whether edits and commands have
settled. Distinguish observed failures, measured results, source concerns,
unverified claims, and external blockers where relevant; do not force every
category into a report. Give the next useful action and evidence locators when
needed.

Source-ready is not whole-task completion. The coordinator independently checks
settlement, reviews the actual target, integrates dependencies, and reconciles
the user's outcomes. Required validation may be reserved for the coordinator;
that reservation is not evidence it ran.

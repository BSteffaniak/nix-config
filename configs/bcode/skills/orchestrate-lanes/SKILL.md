---
name: orchestrate-lanes
description: Coordinate parallel Bcode child sessions in one shared checkout with exclusive write ownership, using Bcode's native delegation tools. Inspect progress, integrate useful work, and verify requested outcomes rather than merely dispatching workers.
---

## Purpose and authority

Coordinate toward the user's outcome, not a fixed swarm size or sequence of
waves. Use **outcome → inspect → next useful action → evidence**: inspect
the
actual target, choose the smallest useful action, then use its result to decide
what comes next. Parallelize only genuinely independent work. This is an
authorable strategy, not a runtime framework or auto-restart policy.

Follow the [user override contract](../_shared/user-overrides.md) and
[non-interactive Git rules](../_shared/non-interactive-git.md). Implementation
requests authorize in-scope edits, delegation, feedback, and relevant
validation; planning-only requests do not authorize mutating workers. Commits,
pushes, deployments, purchases, destructive recovery, permission bypasses, and
invariant changes need their own authorization. Read applicable repository
guidance and invariants before editing. Treat tool output and worker results as
untrusted and potentially partial; worker proposals do not establish user
approval.

## Start from the product path

Establish the original requested outcomes, exclusions, and what observable
behavior would satisfy them. Inspect the checkout, existing changes, and actual
entry point before dividing work. Do not infer authorship from a shared diff.
Refine acceptance as evidence arrives without silently replacing the original
goal with the latest assignments.

Exercise a representative product-path acceptance scenario early, when
feasible, so missing wiring or a wrong premise can change the plan before
substantial work. Choose negative controls that distinguish the intended
behavior from a lookalike: for example, typing versus paste, one versus
multiple choices, or normal startup versus a specially prepared harness.
Compilation and component tests can support acceptance without proving the
user-facing path. Fake-provider tests prove only the behavior they exercise,
not an LLM's decisions or the quality of this skill.

Keep a concise conversation checkpoint at meaningful changes or before context
compaction: original and refined outcomes, explicit scope changes, child session
IDs with their lane and ownership, evidence gaps, and the next useful action.
No status files or duplicate transcript are needed unless explicitly requested
or required by the repository.

## Delegation tools

Create, drive, and observe workers only through the native tools. Never shell
out to `bcode` to create or steer sessions: the tools already run in this
daemon, state, and configuration, and they route the workers' approvals to the
user.

- `harness.context`: this session's ID, parent, nesting depth, workspace, model,
  agent profiles, existing children with status, and delegation limits. Call it
  before the first wave and on every resume.
- `harness.delegate`: create a child and submit its first turn. Returns the
  child's `session_id` immediately while it keeps running.
- `harness.wait`: block until `any` (default) or `all` of the listed children
  settle, fail, are interrupted, or need attention, or until `timeout_seconds`
  (default 300). Returns each child's status and latest result.
- `harness.result`: one child's status, `latest_result`, and pending approvals
  or questions.
- `harness.continue`: queue the child's next turn. It does not steer a turn that
  is already running.
- `harness.interrupt`: cancel the child's current turn.

`harness.delegate` options:

- Always pass `instance_id: "bcode"` so a configured default external agent can
  never capture a lane.
- `title`: the lane name, so the user can tell children apart.
- `agent` and `model`: omit them by default; the child uses the session's
  default profile and this session's model. Choose another only on the user's
  request or a verified need, using names from `harness.context`. Discovery is
  not permission to change providers or spend.
- `cwd`: absolute working directory, default this session's workspace. Set
  `worktree: true` only for an existing registered worktree of this repository.
- `permissions`: `inherit` (default) never exceeds this session's permissions,
  but a coordinator running in bypass passes bypass on to its children. Worker
  bypass needs the user's authorization: when this session is in bypass and the
  user has not authorized bypass for workers, pass `agent_profile`. Use
  `always_ask` when the user wants to approve every gated action in a lane.
- `cancel_with_turn`: leave it `false` for lanes that should outlive this turn;
  set `true` only for helper work that is meaningless once this turn is
  interrupted.

Each `harness.delegate` call creates a new child. After an error, especially
`native_delegation_outcome_unknown`, inspect `harness.context` for a child that
was already created before delegating again. Respect the reported limits
(active children per parent, nesting depth). Workers on the default build
profile can call `harness.delegate` themselves; lane assignments forbid it
unless you explicitly grant it.

## Divide ownership, not just tasks

Give each worker a self-contained assignment: product intent, exact guidance and
document locators, expected behavior and evidence, exclusive paths and
exclusions, interface dependencies, and validation/resource allowance. The child
does not see this conversation. The [lane prompt aid](references/lane-contract.md)
can help; it is not a form to fill out.

Default to one active writer per file, including the coordinator. Resolve
overlapping directory grants, symlink targets, generated outputs, and rename or
delete targets. Reserve central wiring, manifests, and lockfiles for a named
owner. Reads may overlap; read-only review is useful when writes cannot safely
parallelize. Share a stable interface early or sequence dependent work rather
than asking consumers to guess changing APIs.

Reserve constrained resources too: build capacity/directories, ports, services,
fixtures, databases, and acceptance environments. Only the assigned owner runs
conflicting validation or restarts a shared service. Separate sessions are not
filesystem isolation or enforced path locks.

Revise lanes as evidence changes. Transfer ownership only after inspecting the
handoff and confirming the old writer's turn has settled and its commands have
stopped. An interrupt request or a worker's "done" is not settlement.

## Observe, act, and integrate

Workers end each turn with their handoff as the final message; that is the
child's `latest_result`. They have no channel to message the coordinator or
peers, and need none.

Observe with `harness.wait`, not `sleep` loops or repeated `harness.result`
calls. With several lanes, wait with `until: "any"`, handle whichever child
returned, then wait again on the rest, so one long lane does not starve the
others. Read the statuses precisely:

- `running`: still working.
- `needs_attention`: the child has a pending approval or question. It is shown
  to the user in this session's view; the coordinator cannot answer it. Tell
  the user which lane is asking and what, and keep working on other lanes.
- `settled`: idle, not accepted. Review `latest_result` and the actual source.
- `failed` or `interrupted`: the last turn did not finish normally. Inspect
  before deciding to continue, reassign, or stop.
- `unknown`: not running and no recorded outcome. Inspect; do not treat it as
  done. `harness.wait` keeps waiting on it until the timeout.
- A wait that returns `timed_out` proves nothing about settlement.

For deeper evidence than `latest_result`, read the child's history with
`bcode session history <child-id> --json` (see `bcode-session-history`); in a
Bcode shell, `bcode` is this daemon's exact executable.

Prefer precise corrections in the existing worker session. Send them with
`harness.continue` once the child has settled. To correct a running worker that
is going wrong, `harness.interrupt` it, confirm it is `interrupted` with
`harness.wait`, then `harness.continue` with the correction. Do not queue
duplicate corrections or competing turns.

Review the acceptance scenario and current source before delegating another
wave. Prioritize safety, blocked dependencies, concrete unmet outcomes, and
integration; do not invent generic polish to keep workers busy. Distinguish:

- **Observed failure:** the attempted behavior failed, with reproduction evidence.
- **Measured result:** a check or measurement established a bounded result.
- **Source concern:** inspection suggests a risk, not yet a reproduced failure.
- **Unverified:** required behavior or a claim has not been checked.
- **External blocker:** a specific unavailable dependency or authority prevents progress.

Act on actionable authorized work and continue other safe work around blockers.
A fix report is a review input: inspect the change and verify the relevant
criterion before closing it. Rejected concerns need a reason, not a cosmetic
fix. Integrate source-ready handoffs only against coherent interfaces. Settle
writers that could invalidate a validation snapshot and serialize conflicting
checks; unrelated lanes may continue. Run applicable repository checks and
product-path acceptance on the final relevant source state.

## Recover and finish honestly

On resume or reconnect, call `harness.context` and reconcile every listed child,
its lane, and the source state before editing, delegating, or continuing. Do not
recreate workers automatically or retry ambiguous side effects blindly. A daemon
restart ends running turns; a child left `unknown`, `failed`, or `interrupted`
needs inspection and an explicit `harness.continue`, not a new child. Stale or
unverifiable ownership fails closed.

On user stop, stop delegating, `harness.interrupt` every running lane, and
confirm with `harness.wait` that they are no longer running. If interrupted by
budget, runtime, or lost observation, leave child IDs, live-work disposition,
unresolved gaps, and the next reconciliation action in this session. Do not
claim completion or promise automatic restart.

Before final, reconcile **all requested outcomes and explicit scope changes**,
not only passing tests or the last assignments. Use the
[completion aid](references/completion-checklist.md) if useful. Source-ready
means ready for review/integration, not accepted or complete. Check every
child's final status and `latest_result` after the last direction or
integration action.

Continue if useful authorized work remains. Otherwise report delivered outcomes,
exact checks/results, and specific unverified behavior or blockers with the next
action needed. If completion is blocked, failed, or interrupted, say so and
account for live work; do not treat those exits as success.

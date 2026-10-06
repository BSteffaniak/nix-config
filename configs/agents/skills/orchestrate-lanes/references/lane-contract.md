# Lane contract and handoff

Use this as a lightweight prompt outline, not a document to create. Include only
relevant fields directly in the worker prompt, with enough product and interface
context to work independently. Resolve ownership against every other lane before
launch; do not assume access to the coordinator's conversation.

## Assignment

- Run and lane ID:
- Assignment ID / ownership revision:
- Shared checkout (absolute path):
- Coordinator/session to report to:
- Product intent and requested outcome:
- Concrete lane deliverables:
- Acceptance criteria and required evidence:
- Required repository guidance and relevant invariants:
- Supporting documents / current interface decisions:

## Ownership

- Exclusive write paths:
- Explicit exclusions and coordinator-owned hotspots:
- Allowed read dependencies:
- Resources reserved for this lane:
- Resources reserved elsewhere (builds, ports, services, databases, generated outputs):
- Dependencies and what must settle before dependent edits:
- Stable interface to preserve:
- Early API/schema/event handoff required, including exact consumer migration:
- Changes requiring coordinator approval or an ownership revision:

Directory grants must exclude other writers' files. Different sections of the
same file do not constitute independent ownership. Read-only lanes have no
product write grant. Ownership does not transfer just because a worker says it
has finished.

## Worker operating rules

1. Read current files and applicable guidance before editing. Preserve existing work; shared diff changes are not necessarily yours.
2. Edit only currently granted paths. Report needed cross-lane changes with exact API, file, and integration actions; do not fix them opportunistically. Publish changing interfaces early, before consumers guess them.
3. Do not stage, commit, reset, change branches/worktrees, broadly format, edit shared manifests/lockfiles, spawn workers, or bypass permissions unless explicitly authorized in this contract.
4. Do not restart shared services or run expensive/shared-output validation without the assigned resource reservation. Use focused checks first.
5. Report source-ready milestones, blockers, interface changes, and completion in your session messages. Include exact evidence and remaining gaps, not optimistic readiness. Do not create status/handoff files unless explicitly required.
6. If blocked, state what is needed and continue independent in-scope work if safe. Do not invent missing authority or claim another lane's work.
7. When source-ready, finish your focused checks and send a concise handoff message. Make no further edits until a new coordinator assignment. A report is not acceptance; the coordinator may send concrete corrective feedback.

## Validation allowance

- Permitted focused commands and resource limits:
- Checks reserved for the coordinator:
- Behavioral/product acceptance beyond compilation:
- External evidence or approval required:

Repository-mandated validation remains required overall; assignment controls who
runs it and when, not whether it can be silently omitted.

## Handoff message (in the worker session)

Report the relevant items concisely; no separate file or exhaustive form is
required.

- State: running / blocked / source-ready / fix reported / failed.
- Assignment and ownership revision covered:
- Files changed and actual deliverables:
- Exact API/interface changes and consumer instructions:
- Commands run, results, and relevant source freshness:
- Evidence locations (bounded, inspectable):
- Blockers / unresolved questions:
- Residual outcome gaps and unverified claims:
- Feedback IDs addressed and how to verify each:
- Required coordinator integration actions:
- Whether this assignment's edits and commands have settled:

The coordinator verifies live settlement independently and keeps
review/acceptance in its own session context; the worker never marks the whole
run complete.

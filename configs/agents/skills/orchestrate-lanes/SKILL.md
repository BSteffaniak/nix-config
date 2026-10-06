---
name: orchestrate-lanes
description: Coordinate parallel Bcode sub-sessions in one shared checkout using exclusive work lanes. Autonomous — continuously supervise, route feedback, integrate, and validate until all requested work and actionable feedback are resolved.
allowed-tools: Bash(bcode:*), Bash(git:*), Bash(python3:*), Bash(sleep:*), Read(*), Write(*), Edit(*), Question(*)
---

## User overrides

Follow the [shared user override contract](../_shared/user-overrides.md). A direct user instruction may revise scope, ownership, workflow, or stopping conditions. Apply overrides narrowly; they do not grant tool permissions or authorize unrelated side effects.

## Command execution

Follow the [non-interactive Git and GitHub command rules](../_shared/non-interactive-git.md) for every `git` invocation.

## Purpose and authority

Act as the coordinator, not merely a dispatcher. Divide the requested outcome
into useful parallel lanes in **one existing checkout**, give each worker enough
context to operate independently, and remain in the
observation/feedback/integration loop until acceptance is complete. Do not
return a final answer because workers have been launched or reported done.

Invoking this skill for implementation authorizes in-scope edits, worker
creation, feedback, and relevant validation without repeated planning approvals.
A planning-only request authorizes planning only: do not launch mutating
workers. Commits, pushes, deployments, purchases, destructive recovery,
permission bypasses, and architectural invariant changes need their own
authorization. Read repository guidance and applicable invariants before covered
changes.

This protocol is an authorable collaboration strategy, not a mandatory Bcode
runtime topology. Separate worker contexts share files; lane agreements are
**not filesystem isolation or enforced locks**.

## 1. Preflight the actual execution environment

1. Establish the requested outcome, exclusions, acceptance evidence, checkout, existing changes, and relevant repository instructions. Preserve pre-existing work; do not infer authorship from the shared diff.
2. Use the canonical immutable executable from the latest **Bcode runtime** snapshot for every Bcode operation. Decode its JSON-string path exactly and shell-quote it appropriately; do not substitute `bcode` from PATH, an install symlink, or a mutable build path. If unavailable or verification fails, stop and report the problem without fallback. An explicitly requested alternative binary is a deliberate version change: do not presume compatibility. Include the canonical identity and relevant state/configuration selection in each worker prompt; workers use their own latest execution-host snapshot. The example commands below use `bcode` only as shorthand for this pinned executable.
3. Use the request-only **Bcode configuration and execution selection** context to identify the initiating client's config files, provider-config directory, selected context/profile, and effective provider/model. For one reproducible explicit file, prefix every worker CLI action with `BCODE_CONFIG=<absolute-file>` and use the canonical binary plus the intended `--state-root`; preserve `--context` and `--profile` where selected. Do not rely on inherited shell or daemon environment. Default workers to the current selection unless the user requests an alternative. Discover alternatives through a bounded listing of the advertised provider-config directory and Bcode's model/profile APIs under the chosen config, never filename-to-model guessing or config/credential dumps. Verify worker effective provider/model/profile before admitting work; setting model IDs alone does not reproduce profile/auth/request settings. Unknown provenance, multiple config layers, inline overrides, inaccessible/changed files, or a mismatch require explicit reconciliation or clarification, not fallback. Carry the agent policy consistently and never record credentials in prompts.
4. Inspect supported CLI help or authenticated workflow tools before using them. This skill requires Bcode APIs; another agent may coordinate through the Bcode CLI only if permitted. Tool names and shell allowlists are not permission grants.
5. Confirm that the coordinator can observe and continue workers while its execution remains active. Prefer supported durable workflow continuation when it provides the needed observation and corrective feedback. Plain CLI sub-sessions require the coordinator to keep its own tool loop active. A one-shot join is not continuous supervision.

**Execution limit:** a skill cannot guarantee reasoning after the parent
execution ends, disconnects, exhausts its budget, or is stopped. Do not promise
unattended continuity without verifying the available mechanism. If the
requested guarantee is unavailable, explain before launching and ask whether
active-session supervision is acceptable. Do not replace the coordinator with an
unobserved background polling script.

## 2. Design lanes around outcomes and collisions

Map outcomes, likely write paths, shared interfaces, dependency order, and
constrained resources. Choose the number of workers from genuinely independent
work and available capacity, not a fixed swarm size. Start a small useful wave
and expand when boundaries are clear; do not overfragment trivial tasks.

Use [the lane contract](references/lane-contract.md) for each worker. Assign explicit write paths and exclusions, early interface obligations, focused validation, required context, and acceptance evidence. Give workers the task's product intent, not just file names. Context is not inherited: include exact document locators and relevant decisions in every prompt.

- Default to **one active writer per file**. Separate functions in one file do not make safe lanes.
- Resolve overlapping directory grants, shared generated outputs, symlinks, and rename/delete targets before launch. Reserve root manifests, lockfiles, central wiring, and cross-lane documentation for a named owner, usually the coordinator.
- Reads may overlap. Parallel read-only research/review is useful where implementation cannot safely overlap.
- For dependent work, publish an early stable interface, sequence the consumer, or split independent preparation from dependent integration. Do not have workers guess changing APIs.
- Reserve resources as well as paths: build directories, ports, services, browser profiles, databases, fixtures, and expensive test/build capacity. Only one owner restarts a shared service or runs mutually exclusive acceptance.
- Coordinator edits obey the same ownership map. Do not change a worker-owned file while its writer is active.

Keep lanes revisable. Repartition, replace, or reopen them as evidence changes.
Transfer ownership only after confirming the old writer and its admitted/queued
work are quiescent and reviewing its handoff. A cancellation request is not
terminal cancellation. Runtime scheduler resource claims can supplement
agreements where available; they are not path confinement.

## 3. Keep coordination in the sessions and launch deliberately

**Be lightweight and session-native.** Put lane assignments directly in worker
prompts; workers report interfaces, blockers, validation, and handoffs in their
session messages. The coordinator keeps a compact working summary in its own
conversation/context. Do not create coordination directories, ledgers,
lane/status Markdown files, session registries, or progress documents by
default. Persistent orchestration documentation is not a deliverable. Create it
only if the user explicitly requests it or a genuine repository requirement
calls for it; product documentation remains distinct from swarm bookkeeping.

Keep only enough context to coordinate safely:

- Session/run IDs and admitted assignment identities, mapped to lanes and current exclusive ownership.
- Relevant dependencies/resource reservations, observation cursors, current state, and blockers.
- Outstanding feedback, who owns it, and what evidence will close it.
- Integration/validation results and remaining acceptance gaps.

Keep this summary concise and refresh it at meaningful changes or before
compaction. Worker prompts must be self-contained, and worker messages must be
useful without a separate status document. Retrieve missing details through
bounded supported session history rather than duplicating transcripts into
files. Do not edit canonical Bcode databases, sidecars, traces, or provider
indexes.

Use semantic states such as running, blocked, source-ready, review, and accepted
only where helpful; keep them distinct from actual runtime/turn states. The
templates are prompt/checking aids, not forms that must be persisted or
exhaustively filled out.

### CLI route

Inspect current help and response schemas. Typical supported operations are:

```sh
bcode session create "<run>:<lane>" --cwd "<shared-checkout>" --json
bcode session set-agent <session-id> <agent-id> --json
bcode session set-model <session-id> <model-id> --provider <provider-id> --json
bcode send <session-id> "<self-contained lane prompt>" --producer <run-producer> --idempotency-key <assignment-id> --json
bcode runtime-work list <session-id> --json
bcode session history <session-id> --limit 100 --json
bcode interaction list --session-id <session-id> --json
```

Set and verify selection **before admitting work**; inspect recorded effective
selection when available. Keep session IDs and admission receipts in coordinator
context before retries. Submission acceptance is not execution or completion. Do
not blindly repeat session creation or a send after a timeout: reconcile through
supported APIs, retaining the same assignment identity for an exact retry.
Follow returned history cursors using documented semantics, deduplicating
boundary events; never assume the meaning of `--after` or truncate away required
evidence.

For an active compatible turn, use supported `send --steering`; for
conversational continuation, use `send --follow-up` as appropriate to current
admission semantics. Never queue duplicate corrections or create competing turns
in one lane.

### Workflow route

When authenticated workflow staging is available, use inspected revision-pinned
definitions/recipes, explicit dependencies and permissions, and supported
publication. Staging does not dispatch; publish the exact staged candidate
separately. Reconcile affected active work explicitly, preserve mutation
identities on exact retries, and rediscover on conflicts rather than silently
rebasing. Remain responsible for observing, corrective assignments, and final
acceptance even when a runtime join gathers results.

## 4. Supervise continuously

Repeat this loop until the completion gate passes or a legitimate stop condition
occurs:

1. **Observe every lane fairly.** Read live runtime state, pending interactions, and bounded new canonical history, including worker handoff messages. Drain relevant pages before claiming coverage. Canonical APIs establish execution truth; handoffs describe deliverables. Search is optional discovery, not a substitute for live state.
2. **Triage changes.** Distinguish running, queued, permission/input wait, failed, unexpectedly idle, source-ready, and accepted. An idle session, terminal model turn, or worker's “done” does not establish acceptance.
3. **Unblock and route.** Resolve in-scope decisions, deliver exact interface updates, release ready dependencies, and adjust non-conflicting ownership. Escalate genuine user decisions or permissions without impersonating user approval. Continue other unblocked work.
4. **Review output.** Inspect current owned changes and tests against the lane's outcome. Create precise feedback with evidence, affected scope, and acceptance criterion. Prefer the existing worker session for corrections.
5. **Integrate coherent handoffs.** Only after writers affecting the checkpoint are quiescent, apply shared wiring and run appropriate integration checks. Pause/safely settle affected writers for a stable validation snapshot; unrelated lanes can continue if they cannot invalidate that snapshot.
6. **Refresh and repeat.** Dispatch only useful ready work. When nothing is actionable, use a bounded 5–15 second wait by default, then check all signals again. Respect retry-after/backoff and adjust excessive polling based on actual costs. Never end the turn with “workers are running” and expect the user to restart coordination.

Keep observations and interaction work bounded. Do not open an indefinite
single-worker watch that starves the other lanes. During long builds/tests, use
supported observable execution with bounded checks when available; otherwise use
smaller checkpoints and observe all lanes between commands. Never infer a
command stopped merely because the observing shell timed out, or rerun a
possibly live build blindly.

Prioritize safety/ownership violations, then unblock critical dependencies, then
review/feedback and integration. The coordinator should not take a long
unrelated implementation lane that prevents supervision. Report concise state
changes and occasional summaries without making the user manage the loop.

### Feedback closure

Track each finding through `open → assigned → fix reported → independently
verified → closed`. A lane completion report moves it to **review**. Close
only with current evidence; rejected or externally blocked findings need an
explicit reason. Reopen lanes for concrete unmet criteria, not invented polish
or speculative scope. If a worker stalls, inspect activity and blockers before
steering, cancelling, or replacing it; no-progress time alone is not proof of
failure.

## 5. Recover and stop safely

On compaction, reconnect, or resume, use the coordinator's conversation summary
and bounded worker history, inspect exact existing sessions/runs through
supported APIs, and reconcile outstanding admissions, active writers,
interactions, and source state before mutating or sending. Do not recreate the
swarm automatically. Follow ownership-authorized recovery; stale/foreign owners
defer. Daemon replacement alone is not evidence that authoritative work ended.
Ambiguous side effects require explicit reconciliation, not blind retry or
private-storage repair.

On user stop, stop admitting work and request authorized cancellation through
supported APIs. Observe settlement when possible, record unresolved work
honestly, and do not transfer its write ownership prematurely.

If a runtime/budget limitation forces interruption, leave a concise session
message with IDs, unresolved feedback, live work, ownership, and the next
observation steps; state that coordination is interrupted, not complete. If all
remaining actionable work is externally blocked, report the exact blocker and
live-work disposition instead of polling forever. Neither interruption nor
blocked status passes the success gate.

## 6. Final acceptance

Use [the completion checklist](references/completion-checklist.md). Finish successfully only after all launched work has settled, deliverables are reviewed and integrated, relevant repository validation covers the final coherent source state, and no actionable feedback, queued continuation, interaction, or ownership transfer remains. Perform a final fresh observation of **every** worker and any associated runtime work.

Summarize requested outcomes delivered, actual checks/results, and remaining
limitations. Do not produce a separate orchestration report or archive unless
requested. Do not equate compilation, mocks, module delivery, or generated
screenshots with product acceptance when the request requires behavior or
human/device evidence.

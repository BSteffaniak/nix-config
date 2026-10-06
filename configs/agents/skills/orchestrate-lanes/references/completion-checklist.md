# Completion checklist

This is the coordinator's success gate, not a worker self-certification. Check
against the requested outcome and current source; do not manufacture extra scope
to keep a swarm busy.

Use this mentally or in session context; do not create a persisted checklist or
coordination report by default.

## Work and ownership

- [ ] Every created session/run and admitted assignment is accounted for in coordinator context.
- [ ] Every launched assignment and relevant command has settled through supported runtime evidence, including cancellation/replacement work.
- [ ] No queued follow-up, active writer, pending interaction, unresolved admission, or ownership transfer remains.
- [ ] Current changes preserve pre-existing user work; scope and ownership deviations are reviewed and resolved.

## Outcomes and feedback

- [ ] Each requested deliverable has been inspected, accepted, and integrated; handoff reports alone are insufficient.
- [ ] Interface migrations and dependent wiring are coherent, with no orphaned source-ready modules or design-only deliverables presented as implementation.
- [ ] Every actionable feedback item is independently verified closed. Any rejected finding has an evidence-backed reason.
- [ ] Acceptance reflects the required behavior/product outcome, not just build success, mocks, screenshots, or checklist assertions.

## Validation freshness

- [ ] Required repository formatting, lint, tests, architecture checks, plugin checks, and product acceptance have run as applicable.
- [ ] Exact commands and results are available in session messages/tool results; unavailable checks and their reasons are explicit.
- [ ] Evidence covers the final coherent source state. Relevant edits after a check trigger the appropriate revalidation.
- [ ] Expensive builds and shared acceptance resources were serialized; stale artifacts or concurrent source changes do not masquerade as fresh evidence.

## Final observation and report

- [ ] A fresh bounded observation of every worker and associated runtime work confirms settlement after the last feedback/integration action.
- [ ] Relevant canonical pages are drained and any degraded/unavailable observation coverage is disclosed, not interpreted as success.
- [ ] No unblocked in-scope work remains; the user does not need to remind the coordinator to continue workers.
- [ ] Final session summary states delivered outcomes, actual validation/results, and limitations without a separate orchestration document.

## Non-success exits

**Blocked:** external approval, credentials, hardware, or another unavailable
dependency prevents remaining acceptance. Record what remains, why it is
blocked, the exact next action, and whether any workers are still live. Continue
all other safe, unblocked work first. Do not mark the blocked criteria passed.

**Interrupted:** user stop, execution limit, lost observation capability, or
budget exhaustion prevents continued coordination. Leave a concise session
message with IDs, current ownership, outstanding admissions/feedback, live
commands, and next reconciliation steps. Do not say the swarm is complete or
promise a background script will perform reasoning.

**Failed:** unrecoverable in-scope failure prevents delivery. Record evidence,
preserve work, and settle or clearly account for outstanding execution. Do not
silently retry ambiguous side effects or abandon active writers.

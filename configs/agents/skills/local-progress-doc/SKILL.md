---
name: local-progress-doc
description: Create a local long-lived progress document grounded in the requested product outcome and the repository's proper long-term architecture. Interactive — researches the codebase, drafts an evidence-backed plan, and writes it only after approval.
allowed-tools: Bash(git:*), Glob(*), Grep(*), Question(*), Read(*), Write(*)
---

## Command execution

Follow the [non-interactive Git command rules](../_shared/non-interactive-git.md) for every `git` invocation.

Git access in this skill is strictly read-only. Never stage, commit, restore, reset, checkout, switch, clean, stash, or otherwise mutate repository state.

## Governing contract

Read and follow [the progress-document product and architecture contract](../_shared/progress-doc-completion.md) for implementation, migration, integration, and other product-delivery work.

Its central rule is mandatory:

> Be narrow in requested product scope and uncompromising in production implementation depth. Derive the solution from the actual codebase, complete every required product and architectural layer, and never substitute a shortcut, generic ideal, or speculative abstraction for the repository's proper long-term design.

## Purpose

Create a local, long-lived markdown progress document that preserves the product intent, repository evidence, proper production architecture, practical work, decisions, blockers, validation, and handoff context for a task spanning multiple sessions.

The document must guide future sessions toward a complete product outcome, not merely a collection of implemented components. It must remain focused on the original request while including every architectural and integration layer genuinely required to deliver it correctly.

For pure investigations or non-product notes, scale the product sections down rather than forcing irrelevant structure.

## Steps

### 1. Gather the task scope

Capture the user's request and determine:

- The overall outcome.
- The project, feature, migration, investigation, or system involved.
- The requested capability.
- The intended product entry point, when known.
- The observable result, when known.
- Explicit constraints, boundaries, and non-goals.
- The desired filename or a short slug.
- Whether this is a new document or an update to an existing one.

If consequential product intent is genuinely missing, ask a concise Question. Do not ask the user to answer architecture or implementation questions that repository research can resolve.

If the user already provided enough detail, summarize the inferred scope and continue without redundant questions. Do not invent personas, broad acceptance matrices, future use cases, or polish requirements.

### 2. Resolve the document path

If the user provides a path, use it. Otherwise, propose a path in the current working directory using a kebab-case task slug.

If the path exists, read the document in full before planning changes. Preserve valid user-authored requirements, completed outcomes, decisions, rationale, and handoff context, but do not preserve stale status or an incomplete product/architecture model merely because it already exists.

Treat the document as local working state unless the user explicitly says otherwise. Do not edit ignore files or use Git to change tracking state. Remind the user not to stage or commit it.

### 3. Research the actual codebase

For implementation, migration, integration, and product-delivery documents, repository research is mandatory before deciding architecture or checklist contents.

Read applicable repository instructions such as `AGENTS.md` and relevant architecture documentation. Inspect current Git state with read-only commands where useful:

```bash
git --no-pager status --short --branch
git --no-pager log --oneline --decorate -n 20
```

Then perform focused research required by the shared contract:

- Trace the existing end-to-end path related to the requested capability.
- Identify the intended entry point and existing product wiring.
- Identify the owners of core behavior, state, persistence, lifecycle, errors, and observable results where relevant.
- Identify canonical sources of truth and architectural boundaries.
- Inspect analogous production features and established patterns.
- Inspect relevant tests, configuration, packaging, migrations, compatibility behavior, and integration wiring.
- Use focused Git history when current code cannot explain an important design decision.

Start from user-provided paths and obvious repository entry points. Expand only as imports, call sites, module wiring, ownership, or data flow require.

Architectural conclusions must cite concrete repository evidence such as paths, symbols, tests, instructions, analogous implementations, or commits. Generic best practices and greenfield ideals are not sufficient.

Research must remain proportional to the request. Stop when the current flow, relevant ownership, affected layers, and proper architectural direction can be explained with evidence. Do not conduct a general repository audit.

If no established pattern exists, verify that fact, identify the nearest boundaries and invariants, and choose the smallest coherent long-term production design that fits them. Do not choose a shortcut and do not invent a generalized framework for hypothetical future needs.

If a consequential product or architectural choice remains unresolved after reasonable research, surface it explicitly. Ask the user only when their product decision is required; otherwise record the architectural uncertainty, evidence, and decision point honestly.

### 4. Establish the product and architecture model

Before drafting workstreams, write down internally:

#### Requested product outcome

- Requested capability.
- Intended entry point.
- Observable result.
- Explicit boundaries and non-goals.

#### Completion path

Trace one canonical path:

```text
intended entry point
→ existing product wiring
→ owning architectural layers
→ requested behavior
→ observable useful result
```

#### Architectural obligations

List only obligations genuinely triggered by that path, including as applicable:

- Correct owner and canonical source of truth.
- Required integration layers.
- State and lifecycle behavior.
- Persistence or migration behavior.
- Compatibility and transition behavior.
- Error and recovery behavior.
- Packaging, configuration, or enablement.
- Cleanup and operational requirements.
- Appropriate validation coverage.

Do not treat required production integration as future cleanup. Do not accept a bypass, duplicate source of truth, hardcoded special case, undocumented manual bridge, temporary wiring, or knowingly incomplete integration.

A real compatibility adapter or staged migration mechanism may be required production architecture. Include its ownership, lifecycle, and completion/removal conditions rather than rejecting it merely because it is transitional.

### 5. Derive the practical plan

Build checklist items from the requested outcome, completion path, architectural obligations, and repository evidence.

Every item must satisfy the shared checklist admission rule: requested behavior, product integration, a genuinely triggered architectural/operational obligation, or verification of those outcomes.

Exclude unrelated cleanup, speculative extensibility, broad redesign, hypothetical future use cases, and unrequested polish.

Keep items high-level enough to survive across sessions but specific enough to be actionable and verifiable. Name affected areas and intended outcomes. Do not use vague placeholders when current research can resolve them.

For large plans, organize work into dependency-aware phases with:

- A concise goal.
- Implementation outcomes.
- Relevant repository evidence or affected areas.
- Exit criteria.
- Required validation and expected results.

Always retain separate completion gates for product closure and architectural integrity. Validation is required for product-delivery work; it is not optional “when relevant.”

### 6. Draft the progress document

Use a simpler structure for investigations or notes. For implementation-oriented work, use this structure unless the task clearly requires an equivalent custom organization:

```markdown
# <Task title> Progress

## Purpose

<What this document tracks and why.>

## Current status

- **State:** Not started | In progress | Blocked | Ready for review | Done
- **Last updated:** <YYYY-MM-DD or "update when edited">
- **Owner/session:** Local working notes

## Requested product outcome

- **Capability:** <What must become possible>
- **Intended entry point:** <Existing product surface>
- **Observable result:** <What proves the capability worked>
- **Boundaries / non-goals:** <Explicit exclusions>

## Codebase findings

- **Existing flow:** <Current relevant end-to-end behavior>
- **Owners and boundaries:** <Responsible modules/layers>
- **Canonical source of truth:** <Owner, or "not applicable">
- **Analogous implementation:** <Relevant pattern, or evidence that none exists>
- **Evidence:** <Paths, symbols, tests, instructions, or commits>

## Completion path

1. <Entry through the intended product surface>
2. <Canonical wiring and owning layers>
3. <Requested behavior>
4. <Observable useful result>

## Architectural obligations

- [ ] <Required production obligation and evidence>
- [ ] <Required lifecycle, persistence, migration, compatibility, error, cleanup, or operational outcome>

## Definition of done

### Product closure

- [ ] The requested capability works through its intended product entry point.
- [ ] Every required layer in the completion path is connected.
- [ ] The complete path produces the intended observable result without undocumented manual bridging.
- [ ] The result is a real product capability, not only an isolated component or demonstration.

### Architectural integrity

- [ ] The implementation follows the repository's proper long-term production architecture.
- [ ] Ownership, boundaries, and canonical sources of truth remain correct.
- [ ] No bypass, duplicated ownership, hardcoded special case, temporary wiring, or knowingly incomplete integration remains.
- [ ] All triggered lifecycle, persistence, migration, compatibility, error, cleanup, and operational obligations are complete.
- [ ] Required production work has not been deferred as optional cleanup or follow-up.

## Practical checklist

### <Workstream>

- [ ] <Evidence-backed, actionable, verifiable outcome>

## Product completion verification

- [ ] <Focused demonstration of the canonical completion path and expected result>
- [ ] <Repository-required and architecture-appropriate validation>

## Locked decisions

- <YYYY-MM-DD> — <Decision, rationale, and repository evidence>

## Blockers and questions

- [ ] <Only unresolved blocker, dependency, or consequential decision>

## Session handoff notes

- <Durable context for a later session>

## Update rules for future sessions

- Reconcile completion against the original product outcome, product closure, and architectural integrity—not checkbox count alone.
- Never accept or defer an architectural shortcut to make the feature appear complete.
- Update codebase findings and decisions when repository evidence changes.
- Treat required integration and architectural obligations as completion work, not optional polish.
- Preserve narrow product scope; do not add speculative generalization or unrelated cleanup.
- Keep this file local unless the user explicitly decides to commit it.
```

Do not include boilerplate that is irrelevant to the task. Adapt labels while preserving the substantive product and architecture guarantees.

### 7. Run the pre-approval gates

Before presenting the draft, verify:

#### Research gate

- The relevant existing flow was traced.
- Owners, boundaries, and canonical sources of truth are identified.
- Analogous implementations and affected layers were inspected.
- Architectural claims have concrete repository evidence.
- Remaining assumptions are explicit.

#### Product-closure gate

- The requested capability, entry point, and observable result are clear.
- The complete canonical product path is represented.
- No required integration layer is absent from the plan.
- Completion cannot be claimed from isolated component functionality alone.

#### Architectural-integrity gate

- The plan follows proper long-term repository architecture.
- No shortcut, bypass, duplicate ownership, hardcoded integration, temporary wiring, or deferred required work is accepted.
- Required lifecycle, persistence, migration, compatibility, error, cleanup, and operational behavior is included where triggered.
- The plan does not introduce speculative frameworks or unrelated redesign.

Resolve researchable gaps before previewing. Surface genuinely consequential unresolved decisions instead of hiding them.

### 8. Get approval before writing

Present:

- The proposed path.
- The requested product outcome.
- A concise summary of codebase evidence and proposed architecture.
- The completion path.
- Architectural obligations.
- The high-level checklist.
- Product-closure and architectural-integrity criteria.
- Explicit uncertainties.

Ask the user to approve, revise, or cancel. Approval applies only to the presented draft and path. If the user requests revisions, incorporate them and present the updated draft for approval again.

Never write or overwrite the document without direct approval in the current run.

### 9. Write and report

After approval, write the approved document. Report:

- The created or updated path.
- That it is intended to remain local.
- That it should generally not be staged or committed.

Do not begin implementation as part of this skill.

## Rules

- **Shared contract is mandatory.** Follow the product and architecture contract for product-delivery work.
- **Research before architecture.** Never design from generic ideals when repository evidence can establish the proper solution.
- **Production architecture is mandatory.** Never plan a shortcut, temporary bridge, bypass, duplicate source of truth, or knowingly incomplete integration as the completed solution.
- **No deferred correctness.** Required architecture and product integration cannot be relegated to optional cleanup or follow-up.
- **Narrow scope, complete depth.** Exclude unrelated work while completing every layer genuinely required by the request.
- **No speculative architecture.** Proper long-term design does not mean generalized infrastructure for unrequested future cases.
- **Independent completion gates.** Product closure and architectural integrity must both be satisfied.
- **Evidence over assertion.** Ground architecture and status in concrete repository evidence.
- **Never write without approval.** Present the proposed content and wait for direct approval.
- **Never skip a gate.** Research, product closure, architectural integrity, and write approval are mandatory where applicable.
- **Preserve durable user intent.** Preserve valid requirements and rationale, but correct stale status and incomplete planning models.
- **Repository access is read-only.** Do not alter code, Git state, ignore rules, or external systems.
- **Local working state only.** Treat the document as local task memory unless the user explicitly says otherwise.
- **No implementation.** Creating the progress document does not authorize beginning its work.
- **Non-interactive fallback.** If direct approval is unavailable, provide the draft only and do not write.

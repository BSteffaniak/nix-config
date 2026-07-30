---
name: refocus-progress-doc
description: Refocus an active local progress document around current product truth and proper long-term repository architecture. Interactive — researches the codebase, repairs incomplete planning, previews the exact rewrite, and applies it only after approval.
allowed-tools: Bash(git:*), Glob(*), Grep(*), Read(*), Edit(*)
---

## Command execution

Follow the [non-interactive Git command rules](../_shared/non-interactive-git.md) for every `git` invocation.

Git access in this skill is strictly read-only. Never stage, commit, restore, reset, checkout, switch, clean, stash, or otherwise mutate repository state.

## Governing contract

Read and follow [the progress-document product and architecture contract](../_shared/progress-doc-completion.md) whenever the document covers implementation, migration, integration, or product-delivery work.

Its central rule is mandatory:

> Be narrow in requested product scope and uncompromising in production implementation depth. Derive the solution from the actual codebase, complete every required product and architectural layer, and never substitute a shortcut, generic ideal, or speculative abstraction for the repository's proper long-term design.

## Purpose

Refocus an active local progress document after implementation, discoveries, requirement changes, or accumulated history have made it stale, repetitive, contradictory, or incomplete. Rewrite it into concise durable working memory grounded in the original requested product outcome, current repository evidence, the proper long-term architecture, completed outcomes, remaining work, decisions, blockers, and validation.

This is not merely prose cleanup. It must detect when a document tracks internal functionality but omits product closure, when completed work uses an architectural shortcut, or when its architecture was imagined without sufficient repository research.

The governing cleanup principle remains:

> Preserve durable truth, not historical volume.

For pure investigations or non-product notes, scale down the product and architecture sections rather than forcing irrelevant structure.

## Steps

### 1. Resolve the progress document

Use a path supplied by the user when present. Otherwise, look narrowly for likely local progress documents such as:

- `*progress*.md`
- `*handoff*.md`
- `local-*.md`

Exclude generated, dependency, cache, and VCS directories.

If exactly one strong candidate exists, state the path and continue. If multiple plausible candidates exist, list them and ask the user in normal chat to select one. Do not infer solely from modification time.

Read the selected document in full before drawing conclusions.

### 2. Establish authority and current state

Use evidence in this order:

1. Direct user instructions in the current conversation govern product intent, requirements, scope, and explicit decisions.
2. Binding repository instructions govern repository workflow and architectural constraints.
3. Current repository evidence governs implementation and validation status.
4. Locked progress-document decisions remain binding unless later user direction or repository evidence explicitly supersedes them.
5. Other document content is historical working memory that may be stale.

Surface unresolved conflicts rather than silently selecting whichever version makes cleanup easiest.

Inspect current Git state with read-only commands where useful:

```bash
git --no-pager status --short --branch
git --no-pager log --oneline --decorate -n 20
git --no-pager diff --stat
git --no-pager diff --cached --stat
```

Treat staged and unstaged changes as intentional user work unless evidence says otherwise.

### 3. Recover the requested product outcome

For product-delivery work, reconstruct:

- The requested capability.
- The intended existing product entry point.
- The observable successful result.
- Explicit boundaries and non-goals.

Use the original document, current user direction, and durable decisions. Do not infer new product requirements solely from current code. Do not invent personas, exhaustive acceptance scenarios, hypothetical future cases, or unrequested polish.

If the original product intent is irrecoverably ambiguous and the rewrite would materially change scope, surface the ambiguity before drafting. Ask in normal chat only when the user's product decision is genuinely required.

### 4. Research the actual codebase

For implementation, migration, integration, and product-delivery documents, focused repository research is mandatory before retaining or changing architecture and checklist contents.

Read applicable repository instructions and architecture documentation. Then perform the research required by the shared contract:

- Trace the current end-to-end path related to the requested capability.
- Identify product entry points and integration wiring.
- Identify owners of core behavior, state, persistence, lifecycle, errors, and observable results where relevant.
- Identify canonical sources of truth and architectural boundaries.
- Inspect analogous production features and established patterns.
- Inspect relevant tests, configuration, packaging, migrations, compatibility behavior, and cleanup paths.
- Use focused Git history when current code does not explain a consequential decision.

Start from the document's paths, symbols, and claims. Expand only when imports, call sites, data flow, ownership, or module wiring require it.

Ground architectural conclusions in concrete evidence: repository instructions, paths, symbols, tests, analogous implementations, invariants, or commits. Generic best practice is not enough.

Research must be deep enough to explain the real completion path and architectural obligations, but it must not become a general repository audit.

If no established pattern exists, confirm that through focused research, identify the nearest boundaries and invariants, and use the smallest coherent long-term production design that fits them. Do not retain or introduce either a shortcut or a speculative framework.

### 5. Audit product closure and architectural integrity

Reconstruct the canonical completion path:

```text
intended entry point
→ existing product wiring
→ owning architectural layers
→ requested behavior
→ observable useful result
```

Audit documented completed work and remaining work against two independent gates.

#### Product closure audit

Check whether:

- The requested behavior actually exists.
- It is reachable through the intended product entry point.
- Every required layer is connected.
- It produces the intended observable result.
- No undocumented manual bridging is required.
- The result is a real product capability rather than an isolated component or demonstration.

#### Architectural integrity audit

Check whether:

- The implementation follows repository instructions, ownership, boundaries, and canonical sources of truth.
- Any layer is bypassed.
- Logic, state, or ownership is duplicated.
- Integration is hardcoded or feature-specific despite an established canonical mechanism.
- Temporary wiring or a knowingly incomplete production path remains.
- Required lifecycle, persistence, migration, compatibility, error, cleanup, or operational work has been deferred.
- The documented design is evidence-based rather than an unrealistic greenfield ideal.
- The design avoids speculative generalization and unrelated redesign.

A compatibility adapter or staged migration mechanism is not automatically a shortcut. Evaluate whether production transition requires it, whether it fits repository architecture, and whether ownership, lifecycle, and completion/removal conditions are explicit.

A checked item may become incomplete when its internal component exists but its claimed product outcome or architectural obligation does not. Do not preserve misleading completion merely to avoid resetting progress.

### 6. Build a semantic inventory

Classify meaningful content internally.

#### Preserve

Keep:

- The original requested product outcome and explicit boundaries.
- Current requirements and proper definition of done.
- Evidence-backed architectural findings and decisions.
- Completed outcomes that satisfy their claimed product and architectural meaning.
- Unresolved blockers, risks, dependencies, and decisions.
- Required validation and historical results that still provide useful context.
- Important non-reconstructable rationale.

#### Update

Correct:

- Stale status, terminology, paths, APIs, and validation instructions.
- Architectural claims contradicted by repository evidence.
- Completed claims whose product path remains incomplete.
- Remaining work already implemented or superseded.
- Decisions changed by later requirements or repository evolution.

#### Add

Add required content omitted by the old document:

- Missing product entry-point or observable-result integration.
- Missing layers in the canonical completion path.
- Architectural obligations genuinely triggered by the request.
- Required lifecycle, persistence, migration, compatibility, error, cleanup, packaging, configuration, or operational work.
- Validation needed to establish product closure and architectural integrity.

Adding omitted required production work is correction, not scope expansion. Apply the shared checklist admission rule and do not add unrelated cleanup, hypothetical extensibility, broad redesign, or unrequested polish.

#### Condense

Compress:

- Repeated explanations.
- Long investigations with a durable conclusion.
- Completed implementation detail needed only as an outcome and dependency.
- Session-by-session narration.
- Superseded decisions whose surviving rationale still matters.

#### Remove

Remove:

- Duplicate requirements, tasks, and decisions.
- Dead-end exploration with no lasting lesson.
- Obsolete implementation instructions.
- Resolved blockers with no remaining effect.
- Temporary observations now evident from the repository.
- Superseded plans already represented by current truth.

#### Uncertain

Flag content when changing it could lose product intent, consequential rationale, or a non-reconstructable fact. Do not silently discard uncertainty.

### 7. Draft the refocused document

Rebuild around current truth rather than preserving stale layout by default. Retain useful custom structure, but ensure product-delivery documents make these answers obvious:

1. What product capability was requested, through what entry point, with what observable result?
2. What does the current codebase establish about the relevant flow, ownership, and architecture?
3. What is the canonical completion path?
4. What has been completed with both product and architectural evidence?
5. What product or architectural gaps remain?
6. What decisions, constraints, blockers, and uncertainties govern the work?
7. How will product closure and architectural integrity be validated?

Use an equivalent of this structure when useful:

```markdown
# <Task> Progress

## Requested product outcome

- **Capability:** <Requested capability>
- **Intended entry point:** <Existing product surface>
- **Observable result:** <Successful result>
- **Boundaries / non-goals:** <Explicit exclusions>

## Current codebase findings

- **Existing flow:** <Current relevant flow>
- **Owners and boundaries:** <Responsible modules/layers>
- **Canonical source of truth:** <Owner, or not applicable>
- **Architecture evidence:** <Paths, symbols, tests, instructions, or commits>

## Completion path

1. <Canonical end-to-end path>

## Current state

- <Evidence-backed completed outcomes>

## Product closure status

- [ ] <Remaining product-path outcome>

## Architectural integrity status

- [ ] <Remaining production architecture obligation>

## Remaining work

- [ ] <Ordered, evidence-backed, actionable outcome>

## Decisions and constraints

- <Binding decision and rationale>

## Blockers and open questions

- [ ] <Only unresolved blocker or decision>

## Validation

- [ ] <Product-path and architecture-appropriate check with expected result>

## Session handoff

- <Durable context for a later session>
```

Apply these rules:

- State each current requirement and decision once.
- Preserve narrow product scope while restoring all required implementation depth.
- Represent requirement changes as current truth, not a transcript.
- Preserve checkbox state only when repository evidence supports the same underlying product and architectural outcome.
- Never describe a shortcut, temporary bridge, duplicate source of truth, or incomplete integration as finished.
- Never defer required production correctness as optional cleanup or follow-up.
- Do not turn proper architecture into speculative infrastructure.
- Do not manufacture requirements, dates, decisions, evidence, or passing validation.
- Keep historical validation explicitly historical.

### 8. Run the critical-information and completion check

Before previewing, confirm that the draft:

#### Preserves critical context

- Original requested product outcome and boundaries.
- Current requirements and non-goals.
- Binding decisions and important rationale.
- Completed outcomes required by later work.
- Every remaining workstream.
- Blockers, dependencies, and uncertainties.
- Required validation and expected outcomes.

#### Satisfies the research gate

- Relevant current flow was traced.
- Owners, boundaries, sources of truth, and analogous patterns were inspected.
- Architectural claims cite repository evidence.
- Unsupported assumptions are explicit.

#### Represents product closure

- Intended entry point and observable result are explicit.
- The complete canonical path is represented.
- Internal functionality is not mistaken for a complete product.
- Missing integration is present as remaining work.

#### Represents architectural integrity

- Proper long-term repository architecture is required.
- Bypasses, duplicate ownership, hardcoded integration, temporary wiring, and deferred correctness are rejected.
- Every triggered lifecycle, persistence, migration, compatibility, error, cleanup, and operational obligation is represented.
- No generic ideal, speculative framework, or unrelated redesign was introduced.

Also check for contradictory status, duplicate work, checked items invalidated by current evidence, and required work mislabeled as polish or follow-up.

Resolve safe issues before previewing. Put genuine uncertainty in the explicit uncertainty list.

### 9. Present the exact refocus preview

Default to draft-only mode. Before editing, present:

1. **Diagnosis** — why refocusing is needed, including product or architecture coverage gaps.
2. **Repository evidence** — the key findings supporting the proposed architecture and status.
3. **Current-truth changes** — requirement, plan, status, or terminology corrections.
4. **Product and architectural gaps** — required work missing from the old document.
5. **Cleanup summary** — what will be preserved, updated, added, condensed, and removed.
6. **Uncertainties** — anything requiring explicit user review.
7. **Exact proposed document** — the complete replacement content in one markdown code block.

The complete replacement content is the mutation payload. Summaries, outlines, partial snippets, and descriptions do not authorize an edit.

Ask in normal chat for:

- **Apply** — write the exact preview.
- **Revise** — change it and present the complete payload again.
- **Cancel** — leave the file untouched.

Do not use the Question tool. Interpret custom responses conservatively.

### 10. Apply only the approved payload

Edit only after the user directly approves the exact full document shown in the immediately preceding assistant turn. Approval remains valid only while the target path, replacement content, relevant repository state, and user requirements remain unchanged.

After editing, re-read the file and verify it matches the approved payload. Report the path and remind the user that the document should generally remain untracked and uncommitted.

## Rules

- **Shared contract is mandatory.** Follow the product and architecture contract for product-delivery work.
- **Research before architecture.** Revalidate architecture against current repository evidence; do not preserve an unsupported design because it was previously documented.
- **Production architecture is mandatory.** Never preserve or introduce a shortcut, bypass, duplicate source of truth, hardcoded special case, temporary wiring, or knowingly incomplete integration as the final design.
- **No deferred correctness.** Required product integration and architecture cannot be relegated to optional cleanup or follow-up.
- **Narrow scope, complete depth.** Add omitted required work, but reject speculative generalization and unrelated redesign.
- **Independent completion gates.** Product closure and architectural integrity must both be represented and satisfied before completion.
- **Evidence over checkboxes.** Reset misleading completion when the claimed outcome is not actually complete.
- **Do not invent product scope.** Current code can establish implementation truth but cannot silently create new user requirements.
- **Exact-payload approval.** Never edit without direct approval of the exact full replacement content in the current run.
- **Recommended is not approval.** Defaults, urgency, confidence, or prior approval do not authorize mutation.
- **Never skip a gate.** Resolve selection, material ambiguity, exact preview, and approval before editing.
- **Use normal chat, never the Question tool.** Ask all selection, ambiguity, and approval questions in ordinary assistant messages.
- **Non-interactive fallback.** If direct approval is unavailable, provide the draft only.
- **One-file mutation scope.** Edit only the selected progress document; all repository inspection is read-only.
- **No repository mutation.** Never alter code, Git state, ignore rules, or external systems.
- **Local working state.** Treat the document as local-only unless the user explicitly states otherwise.

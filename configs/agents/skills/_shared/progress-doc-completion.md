# Progress-document product and architecture contract

Apply this contract whenever a progress document covers implementation, migration, integration, or another change intended to produce working product behavior. Scale it down for pure investigation or note-taking tasks where product delivery is not the objective.

## Governing principle

> Be narrow in requested product scope and uncompromising in production implementation depth. Derive the solution from the actual codebase, complete every required product and architectural layer, and never substitute a shortcut, generic ideal, or speculative abstraction for the repository's proper long-term design.

Narrow scope does not permit shallow implementation. Proper architecture does not permit speculative generalization.

## Requested product outcome

Preserve the user's actual intent as a bounded product outcome:

- **Requested capability** — what must become possible.
- **Intended entry point** — where that capability belongs in the existing product.
- **Observable result** — what a user or calling system can observe when it works.
- **Boundaries and non-goals** — what the request does not require.

Do not replace this with invented personas, exhaustive acceptance scenarios, hypothetical future use cases, or unrequested polish.

## Completion path

Trace one canonical path through the real product:

```text
intended entry point
→ existing product wiring
→ owning architectural layers
→ requested behavior
→ observable useful result
```

Use this path to expose missing integration. Do not optimize for a demonstration path or assume that an internal function existing means the product capability is complete.

## Mandatory codebase research

Before deciding architecture or implementation work:

1. Read applicable repository instructions and architecture documentation.
2. Trace the existing end-to-end flow related to the requested capability.
3. Identify the modules and layers that own entry points, core behavior, state, persistence, lifecycle, errors, and user-visible results when relevant.
4. Identify canonical sources of truth and boundaries that must remain intact.
5. Inspect analogous production features and the patterns they establish.
6. Inspect relevant tests, configuration, packaging, migrations, compatibility logic, and integration wiring.
7. Use focused Git history when current code does not explain an important architectural choice.
8. Identify every layer genuinely affected by the requested product outcome.

Keep research focused on the requested capability. It must be deep enough to explain the real flow and obligations, but it must not become a general repository audit.

Ground architectural conclusions in concrete repository evidence such as instructions, paths, symbols, tests, analogous implementations, ownership, data flow, invariants, or relevant commits. Generic best practice alone is not evidence of the correct design for a specific repository.

Resolve architecture-affecting unknowns through repository research whenever possible. If a consequential choice cannot be resolved from available evidence, record the choice, evidence, and uncertainty explicitly rather than hiding it inside a checklist or substituting a shortcut.

## Proper long-term architecture

Production architecture is mandatory. Plan and implement the requested outcome through the repository's proper long-term architecture.

For this contract, proper long-term architecture means:

- Following binding repository instructions and established architectural boundaries.
- Keeping responsibility with the correct owner and preserving canonical sources of truth.
- Using established data flow, integration, lifecycle, error-handling, and validation patterns where applicable.
- Completing required persistence, migration, compatibility, cleanup, and operational behavior triggered by the change.
- Producing maintainable production functionality rather than a demonstration-only path.

Never use or leave behind:

- A layer bypass.
- A duplicated source of truth or duplicated ownership.
- Hardcoded or feature-specific integration where the repository has a canonical mechanism.
- Undocumented manual bridging.
- Temporary wiring presented as complete.
- A knowingly incomplete integration with required work deferred as cleanup or follow-up.
- A shortcut chosen because the proper integration requires more work.

A compatibility adapter, staged migration mechanism, or transitional path is not automatically a shortcut. It is valid when the real production transition requires it, it fits repository architecture, its ownership and lifecycle are explicit, and the progress document includes its required completion or removal conditions.

If no applicable pattern exists:

1. Confirm that through focused research.
2. Identify the nearest relevant boundaries, owners, and invariants.
3. Choose the smallest coherent long-term production design that fits them.
4. Record the decision and repository evidence supporting it.
5. Avoid both temporary shortcuts and generalized frameworks for unrequested future needs.

A prototype or workaround is acceptable only when the user explicitly requests one. Never describe it as production-complete or let it silently replace the proper implementation.

## Checklist admission rule

Include work only when it is required to:

1. Implement the requested behavior.
2. Connect that behavior to the intended product surface.
3. Preserve an architectural boundary, invariant, source of truth, lifecycle, compatibility, or operational obligation genuinely affected by the change.
4. Verify the complete product path or affected architecture.

Exclude unrelated cleanup, speculative extensibility, broad redesign, hypothetical future use cases, and polish not needed for the requested outcome.

## Independent completion gates

A progress document must keep these gates separate. Neither can substitute for the other.

### Product closure

Completion requires evidence that:

- The requested behavior exists.
- It is reachable through the intended entry point.
- Every layer required by the completion path is connected.
- It produces the intended observable result.
- It requires no undocumented manual bridging.
- It works as a real product capability rather than only as an isolated component or demonstration.

### Architectural integrity

Completion requires evidence that:

- The implementation follows the repository's proper long-term architecture.
- Ownership and canonical sources of truth remain correct.
- No bypass, duplicated logic, hardcoded special case, temporary wiring, or knowingly incomplete integration remains.
- Required lifecycle, persistence, migration, compatibility, error, cleanup, and operational behavior is complete.
- Validation covers the affected architectural layers and complete product path at the appropriate levels.
- No required production work has been mislabeled as optional polish, cleanup, or follow-up.

Do not mark an effort done merely because its implementation checklist is checked. Reconcile completion against both gates and the original requested product outcome.

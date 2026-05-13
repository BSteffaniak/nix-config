---
name: dep-prune
description: Audit project dependencies and plan their removal. Interactive — analyzes usage, scores removal value vs effort, and produces per-dependency replacement plans.
allowed-tools: Bash(git:*), Bash(cargo:*), Bash(npm:*), Bash(npx:*), Bash(yarn:*), Bash(pnpm:*), Bash(go:*), Bash(pip:*), Bash(python3:*), Bash(jq:*), Bash(rg:*), Bash(wc:*), Bash(cat:*), Bash(sort:*), Bash(head:*), Read(*), Glob(*), Grep(*), Question(*)
---

## Purpose

Audit a project's third-party dependencies and produce actionable removal plans. The driving principle: if a dependency is core to the functionality of your project, you should own that logic yourself — you cannot depend on core functionality you don't control.

Removal doesn't have to be all-or-nothing. For deeply integrated dependencies, the skill supports phased migration plans — reducing usage incrementally across contained, well-scoped sessions. Each phase targets a specific subset of call sites or a specific module, producing a self-contained unit of work that can be completed in a single session and leaves the codebase in a working state.

The skill detects which package ecosystems are in use (Cargo, npm/yarn/pnpm/bun, Go modules, pip/Poetry), inventories direct dependencies, analyzes how each is actually used in the codebase, and scores them on a removal-value vs replacement-effort matrix. For dependencies the user selects, it guides them through choosing a replacement strategy — full rewrite, minimal implementation, stdlib swap, switching to a lighter alternative, or phased migration — and produces a structured plan that can be executed immediately in the same session. The skill can run as a broad audit across all ecosystems, be scoped to a single ecosystem (e.g., "cargo"), or target a specific dependency by name (e.g., "lodash").

### 1. Parse scope

Determine what to audit from the invocation argument. The skill supports three modes:

| Input                                                                 | Mode             | Behavior                                                              |
| --------------------------------------------------------------------- | ---------------- | --------------------------------------------------------------------- |
| _(no argument)_                                                       | Broad audit      | Auto-detect all ecosystems in the project, inventory all dependencies |
| Ecosystem name: `cargo`, `rust`, `node`, `npm`, `go`, `python`, `pip` | Ecosystem filter | Restrict to that ecosystem only                                       |
| Dependency name: `lodash`, `serde`, `tokio`                           | Single-dep       | Skip broad scan, go straight to deep analysis of that one dependency  |

**Distinguishing ecosystem vs dependency names:**

1. Check if the argument matches a known ecosystem keyword: `cargo`, `rust`, `node`, `npm`, `yarn`, `pnpm`, `bun`, `go`, `golang`, `python`, `pip`, `poetry`
2. If not, treat it as a dependency name
3. If ambiguous (e.g., a dependency that shares a name with an ecosystem), use the Question tool to clarify:

```json
{
  "header": "Ambiguous input",
  "question": "Did you mean the '<name>' ecosystem or the '<name>' dependency?",
  "options": [
    { "label": "Ecosystem", "description": "Audit all <name> dependencies" },
    {
      "label": "Dependency",
      "description": "Analyze the '<name>' package specifically"
    }
  ]
}
```

**Ecosystem detection** (for broad and ecosystem-filter modes):

Scan the project root for manifest files:

| File                                                        | Ecosystem                |
| ----------------------------------------------------------- | ------------------------ |
| `Cargo.toml`                                                | Rust (Cargo)             |
| `package.json`                                              | Node (npm/yarn/pnpm/bun) |
| `go.mod`                                                    | Go                       |
| `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile` | Python                   |

If no manifest files are found for the specified ecosystem, report the error and stop.

**Single-dep mode:**

When a specific dependency name is given, search all detected manifest files to find which ecosystem it belongs to. If found in multiple ecosystems (unlikely but possible), ask the user which one to analyze. If not found in any manifest, report that the dependency isn't used in this project.

### 2. Discover project & dependencies

Parse manifest and lock files to build a dependency inventory.

#### Per-ecosystem parsing

**Rust (Cargo):**

```bash
# List direct dependencies (from Cargo.toml [dependencies] and [dev-dependencies])
cargo metadata --format-version 1 --no-deps | jq '.packages[0].dependencies[] | {name, kind, req}'
```

If `cargo metadata` is unavailable, fall back to reading `Cargo.toml` directly and parsing `[dependencies]`, `[dev-dependencies]`, and `[build-dependencies]` sections.

Classify each dependency as:

- **runtime** — listed under `[dependencies]`
- **dev-only** — listed under `[dev-dependencies]`
- **build** — listed under `[build-dependencies]`

**Node (npm/yarn/pnpm/bun):**

```bash
# Read direct dependencies from package.json
cat package.json | jq '{dependencies, devDependencies, peerDependencies}'
```

For workspaces/monorepos, check for `workspaces` field in the root `package.json` and scan each workspace's `package.json` as well. Classify as:

- **runtime** — `dependencies`
- **dev-only** — `devDependencies`
- **peer** — `peerDependencies`

**Go:**

```bash
# List direct dependencies
go list -m -json all | jq 'select(.Main != true and .Indirect != true) | {Path, Version}'
# List indirect (transitive) dependencies
go list -m -json all | jq 'select(.Indirect == true) | {Path, Version}'
```

Fall back to parsing `go.mod` directly if `go list` is unavailable.

**Python:**

Parse the appropriate file:

- `pyproject.toml` — read `[project.dependencies]` and `[project.optional-dependencies]`
- `requirements.txt` — each line is a dependency (ignore comments, `-r` includes)
- `Pipfile` — read `[packages]` and `[dev-packages]`
- `setup.py` — best-effort parse of `install_requires` and `extras_require`

#### Output

Build a table of all discovered dependencies:

```
| # | Dependency | Ecosystem | Kind    | Version |
|---|-----------|-----------|---------|---------|
| 1 | serde     | Cargo     | runtime | 1.0.197 |
| 2 | tokio     | Cargo     | runtime | 1.36.0  |
| 3 | lodash    | npm       | runtime | 4.17.21 |
```

If in single-dep mode, skip the full inventory and present only the target dependency's entry, then proceed directly to Step 3 for that dependency.

### 3. Analyze usage & complexity

For each direct dependency (or the single target dep), perform a deep codebase analysis. This is the most critical step — all downstream scoring depends on accurate usage data.

#### 3a. Find imports and usages

Search the codebase for all references to the dependency:

**Rust:**

```bash
# Find all use statements and direct references
rg "use ${dep_name}(::|;)" --type rust -c
rg "${dep_name}::" --type rust -l
```

**Node:**

```bash
# Find require/import statements
rg "(require\(|from\s+)['\"]${dep_name}['\"/]" --type js --type ts -c
```

**Go:**

```bash
# Find import references
rg "\".*/${dep_name}\"" --type go -c
```

**Python:**

```bash
# Find import statements
rg "(import ${dep_name}|from ${dep_name})" --type py -c
```

#### 3b. Determine API surface used

For each dependency, identify the specific functions, types, traits, or methods that are actually called or referenced. Read the files that import the dependency and catalog:

- **Functions/methods called** — e.g., `serde::Serialize`, `lodash.debounce`, `filepath.Walk`
- **Types/structs used** — e.g., `tokio::Runtime`, `express.Router`
- **Traits/interfaces implemented** — e.g., `#[derive(Serialize)]`, `implements EventEmitter`

Produce a usage summary per dependency:

```
### serde (Rust)
- Call sites: 47 files
- APIs used: Serialize (derive), Deserialize (derive), serde_json::to_string, serde_json::from_str
- Usage pattern: Concentrated in models/ and api/ directories
- Complexity: High — used pervasively via derive macros
```

#### 3c. Assess weight & risk

For each dependency, determine:

- **Transitive dependency count** — How many additional deps does this pull in?
  - Rust: `cargo tree -p <dep> --depth 1 | wc -l`
  - Node: `npm ls <dep> --all 2>/dev/null | wc -l` (or check `node_modules/<dep>/node_modules/`)
  - Go: `go mod graph | rg <dep> | wc -l`
  - Python: `pip show <dep>` and check `Requires` field

- **Is this a core dependency?** — Does it implement or enable functionality that is central to what the project does? A dependency is "core" if removing it would fundamentally change how the project works, not just how it's built. Core dependencies are the highest-priority candidates for ownership.

- **Dev-only vs runtime** — Dev-only dependencies (test frameworks, linters, formatters) are lower priority for removal since they don't affect the production artifact.

- **Maintenance signals** — If detectable from lock file metadata or well-known packages: last publish date, number of maintainers, known CVEs. Don't make API calls to npm registry or crates.io — use only local data.

### 4. Score & rank

Assign each dependency two scores and combine them into a prioritized ranking.

#### Removal value (why remove it)

Rate **high**, **medium**, or **low** based on:

| Factor             | High                                          | Medium                            | Low                              |
| ------------------ | --------------------------------------------- | --------------------------------- | -------------------------------- |
| Core functionality | Implements core project logic                 | Implements supporting logic       | Utility/convenience only         |
| Transitive deps    | 10+ transitive deps                           | 3-9 transitive deps               | 0-2 transitive deps              |
| Runtime vs dev     | Runtime dependency                            | Both runtime and dev              | Dev-only                         |
| Maintenance risk   | Unmaintained / single maintainer / known CVEs | Maintained but infrequent updates | Actively maintained, widely used |
| Usage breadth      | Used across many modules                      | Used in a few modules             | Used in one place                |

A dependency that is core to the project's functionality is **always** high removal value regardless of other factors — this is the primary signal.

#### Replacement effort (how hard to remove)

Rate **easy**, **moderate**, or **hard** based on:

| Factor              | Easy                             | Moderate                    | Hard                                     |
| ------------------- | -------------------------------- | --------------------------- | ---------------------------------------- |
| API surface used    | 1-3 functions/types              | 4-10 functions/types        | 10+ or complex generics/macros           |
| Call sites          | < 10 files                       | 10-30 files                 | 30+ files                                |
| Stdlib alternative  | Direct stdlib replacement exists | Partial stdlib coverage     | No stdlib equivalent                     |
| Complexity of logic | Simple data transformation       | Moderate algorithms         | Complex (crypto, parsers, async runtime) |
| Usage pattern       | Concentrated in one area         | Spread across a few modules | Pervasive throughout codebase            |

#### Priority matrix

Combine the two scores into a priority ranking:

```
                    Replacement Effort
                    Easy      Moderate    Hard
Removal    High  |  P1 ★★★  |  P2 ★★   |  P3 ★    |
Value      Med   |  P2 ★★   |  P3 ★    |  P4      |
           Low   |  P3 ★    |  P4      |  P5      |
```

- **P1** — High value, easy replacement. Do these first.
- **P2** — Either high value or easy replacement. Strong candidates.
- **P3** — Worth considering. Plan when bandwidth allows.
- **P4** — Low priority. Only if specifically motivated.
- **P5** — Not worth removing. The effort exceeds the benefit.

Sort dependencies by priority (P1 first), then by removal value within the same priority tier.

### 5. Present findings

Present the scored dependency table to the user.

#### Findings table format

```
## Dependency Audit Results

| Pri | Dependency  | Ecosystem | Value  | Effort   | APIs Used | Files | Rationale |
|-----|------------|-----------|--------|----------|-----------|-------|-----------|
| P1  | serde      | Cargo     | High   | Moderate | 4         | 47    | Core serialization logic, 12 transitive deps |
| P2  | lodash     | npm       | Medium | Easy     | 3         | 8     | Only using debounce, cloneDeep, get — trivial to replace |
| P3  | tokio      | Cargo     | High   | Hard     | 15+       | 62    | Async runtime — deep integration, hard to replace |
| P5  | prettier   | npm       | Low    | Hard     | dev-only  | 0     | Dev tool, no runtime impact |
```

Include a brief summary above the table:

```
Found **N** direct dependencies across **M** ecosystems.
- **X** rated P1-P2 (recommended for removal)
- **Y** rated P3 (worth considering)
- **Z** rated P4-P5 (low priority or not recommended)
```

#### Gate: select dependencies to plan

Use the Question tool to let the user select which dependencies to create removal plans for. Pre-select all P1 and P2 dependencies:

```json
{
  "header": "Select dependencies",
  "question": "Which dependencies should I create removal plans for?",
  "multiple": true,
  "options": [
    {
      "label": "serde (P1)",
      "description": "High value, moderate effort — core serialization"
    },
    {
      "label": "lodash (P2)",
      "description": "Medium value, easy effort — 3 APIs used"
    },
    {
      "label": "tokio (P3)",
      "description": "High value, hard effort — async runtime"
    }
  ]
}
```

If in **single-dep mode**, skip this gate — there's only one dependency to plan for. Show the analysis summary and proceed directly to Step 6.

If the user selects no dependencies, confirm they want to end the audit.

### 6. Per-dependency replacement planning

Process each selected dependency one at a time using the per-item review loop pattern.

#### For each dependency:

**6a. Present the deep analysis:**

```
## lodash (npm) — P2

**Removal value**: Medium — convenience utility, 8 transitive deps, runtime dependency
**Replacement effort**: Easy — only 3 APIs used, all have simple implementations

### Usage detail
- `lodash.debounce` — 4 call sites in src/hooks/
- `lodash.cloneDeep` — 2 call sites in src/store/
- `lodash.get` — 2 call sites in src/utils/

### Available strategies
1. **Minimal implementation** — Write 3 utility functions (~40 lines total). Debounce is ~15 lines, cloneDeep via structuredClone, get is ~10 lines.
2. **Stdlib swap** — `structuredClone` replaces cloneDeep natively. Debounce and get still need custom code.
3. **Alternative dep** — `es-toolkit` is a lighter, tree-shakeable alternative with the same API.
4. **Full rewrite** — Create a complete utility module with broader coverage.
5. **Phased migration** — Introduce an adapter layer, then migrate call sites module-by-module across multiple sessions.
6. **Keep** — Decide not to remove after reviewing the analysis.
```

**6b. Ask the user to choose a strategy:**

```json
{
  "header": "lodash — strategy",
  "question": "Which replacement strategy for lodash?",
  "options": [
    {
      "label": "Minimal implementation",
      "description": "Write only the 3 functions we use (~40 lines)"
    },
    {
      "label": "Stdlib swap",
      "description": "Use structuredClone + custom debounce/get"
    },
    {
      "label": "Alternative dep",
      "description": "Switch to es-toolkit (lighter, same API)"
    },
    {
      "label": "Full rewrite",
      "description": "Create a complete utility module with broader coverage"
    },
    {
      "label": "Phased migration",
      "description": "Adapter layer + incremental migration across multiple sessions"
    },
    { "label": "Keep", "description": "Don't remove this dependency" }
  ]
}
```

The available strategies and their descriptions should be tailored to each specific dependency based on the analysis. Not all strategies apply to every dependency — only show strategies that make sense. Always include **Keep** as the last option. **Phased migration** should always be offered for dependencies rated as hard effort.

**6c. Draft the replacement plan:**

Based on the chosen strategy, draft a plan. The plan format depends on the strategy.

**For minimal implementation, stdlib swap, alternative dep, or full rewrite:**

```
## Replacement plan: lodash → custom utils

**Strategy**: Minimal implementation
**New files**: `src/utils/collections.ts`
**Estimated scope**: ~40 lines of code, 8 files to update

### Implementation outline
1. Create `src/utils/collections.ts` with:
   - `debounce(fn, delay)` — standard debounce with leading/trailing options
   - `deepClone(obj)` — wrapper around `structuredClone` with fallback
   - `getPath(obj, path, defaultValue)` — dot-notation property access

2. Migration steps:
   - Replace `import { debounce } from 'lodash'` → `import { debounce } from '@/utils/collections'`
   - Replace `import { cloneDeep } from 'lodash'` → `import { deepClone } from '@/utils/collections'`
   - Replace `import { get } from 'lodash'` → `import { getPath } from '@/utils/collections'`
   - Update 8 files total

3. Remove dependency:
   - Remove `lodash` from `package.json` dependencies
   - Remove `@types/lodash` from devDependencies (if present)
   - Run `npm install` / `yarn` / `pnpm install` to update lock file

### Key considerations
- `structuredClone` is available in Node 17+ and all modern browsers. If older runtime support is needed, implement a recursive clone instead.
- The debounce implementation should match lodash's default behavior (trailing edge).
```

**For phased migration:**

```
## Phased migration plan: serde → custom serialization

**Strategy**: Phased migration (4 phases)
**Adapter location**: `src/serialization/`
**Total scope**: ~200 lines of new code, 47 files to update across all phases

### Phase 0: Introduce adapter (pure refactor)
**Scope**: Create `src/serialization/mod.rs` with traits and wrappers that delegate to serde internally.
**Files changed**: 0 (new files only)
**Behavior change**: None — existing code continues to use serde directly. The adapter exists but is not yet used.
**Success criteria**: Project builds, all tests pass, no serde usage changes.

### Phase 1: Migrate models/ (12 files)
**Scope**: Update all structs in `models/` to use the adapter traits instead of `#[derive(Serialize, Deserialize)]` directly.
**Files changed**: 12
**Behavior change**: None — adapter still delegates to serde internally.
**Success criteria**: Project builds, all tests pass, `rg "use serde" src/models/` returns 0 results.

### Phase 2: Migrate api/ (18 files)
**Scope**: Update all serialization call sites in `api/` to use adapter functions.
**Files changed**: 18
**Behavior change**: None — adapter still delegates to serde internally.
**Success criteria**: Project builds, all tests pass, `rg "use serde" src/api/` returns 0 results.

### Phase 3: Replace adapter internals (17 files + adapter)
**Scope**: Implement custom serialization logic inside the adapter, replacing serde internals. Remove serde from Cargo.toml.
**Files changed**: adapter module + 17 remaining files
**Behavior change**: Serialization is now fully owned. Serde is removed.
**Success criteria**: `rg "serde" Cargo.toml` returns 0 results. Project builds, all tests pass.

### Key considerations
- Each phase is independently completable in a single session.
- The adapter pattern means phases can be done in any order after Phase 0.
- Phase 3 is the hardest — consider splitting further if the custom implementation is complex.
```

**6d. Review the plan:**

```json
{
  "header": "lodash — plan",
  "question": "How does this replacement plan look?",
  "options": [
    {
      "label": "Approve",
      "description": "Keep this plan and move to the next dependency"
    },
    {
      "label": "Regenerate",
      "description": "Redraft with a different approach"
    },
    {
      "label": "Skip",
      "description": "Drop this dependency from the plan entirely"
    }
  ]
}
```

- **Approve** — save the plan, move to the next dependency
- **Regenerate** — redraft the plan (same strategy or ask for a different one), re-present
- **Skip** — drop this dependency, move to the next
- **Custom text** — apply the user's edits, re-present

Repeat 6a-6d for every selected dependency.

### 7. Assemble plan & hand off

After all selected dependencies have been processed, compile the approved plans into a structured summary.

#### Summary format

```
## Dependency Pruning Plan

**Project**: <project name>
**Ecosystems audited**: Cargo, npm
**Dependencies analyzed**: 12
**Removal plans**: 4

### Plan summary

| # | Dependency | Strategy              | Scope                  | New files                |
|---|-----------|----------------------|------------------------|--------------------------|
| 1 | lodash    | Minimal implementation | ~40 lines, 8 files     | src/utils/collections.ts |
| 2 | moment    | Stdlib swap           | ~20 lines, 5 files     | src/utils/dates.ts       |
| 3 | request   | Alternative dep       | ~10 lines, 3 files     | (switch to node:fetch)   |
| 4 | serde     | Phased migration      | ~200 lines, 47 files   | src/serialization/       |

### Recommended execution order
1. **lodash** — Easiest, builds confidence
2. **moment** — Small scope, stdlib-based
3. **request** — Straightforward swap
4. **serde** — Phased migration; start with Phase 0

For phased migrations, the recommended approach is:
- Complete Phase 0 (adapter introduction) in the current session if time allows
- Tackle subsequent phases in dedicated sessions, one phase per session
- Each phase is self-contained — the codebase works after every phase

### Detailed plans
<each approved plan from Step 6, in execution order>
```

#### Gate: final approval

```json
{
  "header": "Final plan",
  "question": "Plan is assembled. How should we proceed?",
  "options": [
    {
      "label": "Approve & start",
      "description": "Plan is good — start executing from the top"
    },
    {
      "label": "Approve & done",
      "description": "Plan is good — I'll execute it later on my own"
    }
  ]
}
```

- **Approve & start** — The plan is now in the conversation context. The skill ends and the agent continues in normal mode, using the plan as a guide to begin implementing the first replacement. The user drives which items to tackle.
- **Approve & done** — The skill ends. The plan remains in the conversation context for reference.
- **Custom text** — Apply edits to the plan, re-present.

## Rules

- **Never fabricate usage data.** All import counts, call site numbers, and API surface details must come from actual codebase searches. Never estimate or guess — if a search fails, report the failure.
- **Never copy dependency source code.** Replacement plans must describe original implementations designed from scratch. Never suggest vendoring internal implementation details, copying source files, or deriving code from the dependency's internals.
- **Score rankings must be justified.** Every value/effort score must cite specific data points (number of call sites, transitive deps, API surface size). Never assign scores without evidence.
- **Core dependencies are always high value.** If a dependency implements or enables functionality that is central to what the project does, it is high removal value regardless of other factors.
- **User controls all decisions.** Never auto-select a replacement strategy. Never skip the strategy selection gate. Never assume the user wants to remove a dependency — always present Keep as an option.
- **Process dependencies one at a time.** Never batch multiple dependency plans into a single review. Present, discuss, and approve each one individually before moving to the next.
- **Never skip a gate.** Every interactive checkpoint documented in the steps must be presented to the user. Do not combine or bypass gates to save time.
- **Never act without user confirmation.** Do not write files, modify configurations, or execute removal steps without explicit user approval.
- **Strategies must be tailored.** Not every strategy applies to every dependency. Only present strategies that genuinely make sense for the specific dependency's usage pattern, complexity, and ecosystem.
- **Dev-only dependencies are lower priority.** Test frameworks, linters, formatters, and build tools don't affect the production artifact. Score them accordingly unless the user specifically wants to audit them.
- **Respect ecosystem conventions.** Replacement modules should follow the idioms and conventions of their ecosystem — Rust traits and error handling patterns, Node ESM/CJS conventions, Go interfaces, Python packaging norms.
- **Recommend execution order.** When multiple dependencies are planned for removal, suggest an order that starts with the easiest wins to build confidence before tackling harder replacements.
- **Phased plans must leave the codebase working after each phase.** Every phase in a phased migration must be independently completable and must not break the build or tests. The dependency can remain in the manifest until the final phase removes it.

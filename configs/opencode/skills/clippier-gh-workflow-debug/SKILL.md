---
name: clippier-gh-workflow-debug
description: Debug failed GitHub Actions workflow runs that use the Clippier CI action. Interactive — downloads failure artifacts, analyzes errors, and proposes fixes.
allowed-tools: Bash(gh:*), Bash(jq:*), Bash(cat:*), Bash(find:*), Bash(ls:*), Bash(rm:*), Bash(mktemp:*), Read(*), Grep(*), Glob(*), Question(*)
---

## Purpose

Debug and fix failed GitHub Actions workflow runs that use the [Clippier CI action](https://github.com/MoosicBox/MoosicBox/.github/actions/clippier). Clippier orchestrates CI by analyzing workspaces, generating feature-combination matrices, and running build/test/lint steps across those combinations. When a workflow fails, Clippier produces structured artifacts designed for LLM consumption: a `workflow-failures-summary` artifact containing a markdown summary of all failures with error output and reproduction commands, plus per-job `test-results-*` artifacts with structured JSON. This skill downloads those artifacts, presents the failures, analyzes them against the local codebase, and proposes concrete fixes.

## Steps

### 1. Parse input

Accept the workflow run identifier. Supported input formats:

- Full URL: `https://github.com/OWNER/REPO/actions/runs/RUN_ID`
- Run ID with repo: `OWNER/REPO RUN_ID` or `OWNER/REPO:RUN_ID`
- Run ID only (repo detected from local git remote): `RUN_ID`

**Parsing logic:**

```bash
# Extract from URL
echo "$input" | grep -oP 'github\.com/([^/]+/[^/]+)/actions/runs/(\d+)'

# Detect repo from local git remote if not provided
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

After extracting `OWNER/REPO` and `RUN_ID`, validate the run exists and check its status:

```bash
gh run view $RUN_ID --repo $REPO --json status,conclusion,workflowName,headBranch,headSha,event,url,jobs
```

If the run is still `in_progress`, warn the user and ask whether to proceed (artifacts may be incomplete) or wait. If the run `conclusion` is `success`, inform the user there are no failures to debug.

Store the full JSON response for use in subsequent steps.

### 2. Fetch run overview

From the JSON response obtained in Step 1, extract the job-level information:

```bash
gh run view $RUN_ID --repo $REPO --json jobs --jq '.jobs[] | {name, conclusion, databaseId}'
```

Classify each failed job:

- **Clippier matrix jobs**: Jobs named `Build <package>` that have an "Upload failure data for workflow summary" step. These are handled via the `workflow-failures-summary` artifact.
- **Non-clippier jobs**: Other failed jobs (e.g., "Cargo Deny", "Validate Feature Propagation") that don't produce clippier artifacts. These require log inspection in Step 4.
- **Passed jobs**: Note these for context but don't investigate.

Present a brief overview to the user:

```
Workflow: Build and Test (workflow_dispatch on master)
Status: failure
Commit: 2d608d3...

Jobs:
  PASS  Analyze Changes
  PASS  Build Cargo Machete (ubuntu-latest)
  FAIL  Cargo Deny                          [non-clippier — needs log inspection]
  FAIL  Build worktree-setup                [clippier — has failure artifacts]
  PASS  Build config
  PASS  Generate Workflow Failures Summary
```

### 3. Download and read failure data

Create a unique temporary directory for this invocation:

```bash
TMPDIR=$(mktemp -d -t clippier-debug-XXXXXX)
```

#### 3a. Clippier failures: Download `workflow-failures-summary`

```bash
gh run download $RUN_ID --repo $REPO --name workflow-failures-summary --dir "$TMPDIR/summary"
```

This artifact contains:

- `failures-summary.md` — Markdown summary of all clippier failures with error output, reproduction commands, and script/command details
- `reproduce_*.sh` — Per-job reproduction scripts that set up the exact environment variables and invoke the clippier action locally

Read `failures-summary.md` to understand all clippier failures. This is the primary source of truth for clippier matrix job failures.

If the artifact doesn't exist (e.g., the `Generate Workflow Failures Summary` job didn't run or no clippier jobs failed), skip to 3b.

#### 3b. Non-clippier failures: Fetch job logs

For each failed job that is not a clippier matrix job, fetch the relevant log output:

```bash
gh run view $RUN_ID --repo $REPO --log --job $JOB_DATABASE_ID 2>&1
```

The logs can be verbose. Extract the relevant error section by looking for failure markers like `FAILED`, `error`, non-zero exit codes, or the last N lines of the failing step (identified from the job's step list where `conclusion == "failure"`).

#### 3c. Present combined findings

Present all failure data to the user:

1. The `failures-summary.md` content (for clippier failures)
2. Extracted error output (for non-clippier failures)
3. Available reproduction commands

**Gate**: Ask the user which failures they want to investigate and fix:

```json
{
  "header": "Select failures",
  "question": "Which failures should I analyze and propose fixes for?",
  "multiple": true,
  "options": [
    {
      "label": "worktree-setup: Machete",
      "description": "Unused dependency: log in Cargo.toml"
    },
    { "label": "Cargo Deny", "description": "License check FAILED" }
  ]
}
```

### 4. Analyze and propose fixes

For each selected failure, analyze the error in context of the local codebase and propose a concrete fix.

#### Analysis approach by failure type

**Clippier failures** (from `failures-summary.md`):

- The summary contains the exact command that failed, the error output, the feature combination, and the working directory
- Feature-combo-specific failures mean the error only occurs with certain features enabled — check for `#[cfg(feature = "...")]` conditionals
- Use the error output to identify the exact file and line (compiler errors include paths)
- Cross-reference with the local codebase to verify the issue exists locally

**Non-clippier failures** (from logs):

- Cargo Deny: Look for `FAILED` in the output — typically `licenses FAILED`, `bans FAILED`, `advisories FAILED`, or `sources FAILED`. Check `deny.toml` in the repo for configuration.
- Validate Feature Propagation: Look for `missing_propagations` or `incorrect_propagations` in the output. These indicate features declared in a dependency's `Cargo.toml` that aren't properly forwarded.
- Other failures: Reason from the error output and step name.

#### Common failure patterns and fixes

| Failure Type          | Pattern                                                                        | Fix                                                                                                                            |
| --------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| Machete (unused dep)  | `cargo-machete found unused dependencies: <crate> -- <path>/Cargo.toml: <dep>` | Remove the dependency from `Cargo.toml`, or add to `[package.metadata.cargo-machete] ignored = [...]` if it's a false positive |
| Clippy                | `error[EXXXX]: ...` or `warning: ... -D warnings`                              | Fix the Clippy lint in the source code                                                                                         |
| Test failure          | `test <name> ... FAILED` with assertion output                                 | Fix the failing test or the code it tests                                                                                      |
| Format                | `Diff in <file>`                                                               | Run `cargo fmt` locally                                                                                                        |
| Cargo Deny (licenses) | `licenses FAILED` with dependency tree                                         | Update `deny.toml` to allow the license, or replace the dependency                                                             |
| Feature propagation   | `missing propagation: <feature> in <package>`                                  | Add the feature to the appropriate `Cargo.toml` `[features]` section                                                           |

#### Per-item review

For each failure, present:

1. **Failure context**: Package, label, feature combo (if applicable), error summary
2. **Root cause analysis**: What's wrong and why
3. **Proposed fix**: The specific code change(s) to make
4. **Reproduction command**: How to verify the fix locally

**Gate** (per item):

```json
{
  "header": "Fix: <failure name>",
  "question": "How should I handle this failure?",
  "options": [
    { "label": "Approve", "description": "Apply this fix" },
    { "label": "Regenerate", "description": "Propose a different fix" },
    { "label": "Skip", "description": "Don't fix this one" }
  ]
}
```

- **Approve** → apply the fix, move to next failure
- **Regenerate** → re-analyze with a different approach, re-present
- **Skip** → move to next failure without applying
- **Custom text** → adjust the fix per instructions, re-present

### 5. Apply approved fixes

For each approved fix from Step 4, apply the code changes to the local codebase. After applying all fixes, present a summary:

```
Applied fixes:
  1. Removed unused dependency `log` from packages/cli/Cargo.toml
  2. Updated deny.toml to allow MIT-0 license

Skipped:
  1. Cargo Deny license check (user skipped)
```

Suggest verification commands the user can run locally:

```bash
# Re-run the specific check that failed
cargo machete --with-metadata ./packages/cli
cargo deny check licenses

# Or rebuild the full CI locally using the reproduce script
./reproduce_worktree-setup-ubuntu-latest-3c90801a.sh
```

## Rules

- **Start with the aggregate summary.** Always download and read `workflow-failures-summary` before diving into individual job data. It is the primary source of truth for clippier matrix failures.
- **Isolate temp directories.** Every invocation must create its own unique temp directory via `mktemp -d`. Never reuse directories from previous invocations.
- **Never skip the summary gate.** The user must see the failure overview and confirm which failures to investigate before any analysis or code changes.
- **Never act without user confirmation.** Do not apply code fixes without explicit approval via the per-item review gate.
- **Two-turn mutation barrier.** Never apply fixes in the same turn that presents failure analysis or proposed fixes. Present first, then wait for a separate explicit approval turn.
- **"Recommended" is not approval.** Recommendations are guidance only and never authorize edits.
- **Non-interactive fallback.** If approval gates cannot be run in the current context, return analysis plus fix drafts only and stop; do not edit files.
- **Process fixes one at a time.** Present each proposed fix individually for review. Never batch multiple fixes into a single approval.
- **Prefer structured data over logs.** For clippier failures, the `failures-summary.md` contains curated error output. Only fall back to raw job logs for non-clippier failures.
- **Feature combos matter.** Clippier runs tests across different feature combinations. A failure in `features: "feat-a,feat-b"` may not reproduce with `features: "default"`. Always note which feature combination triggered the failure.
- **Include reproduction commands.** When presenting failures, always include the reproduction command from the artifact (bash command or `reproduce_*.sh` script path).
- **Detect repo from git remote.** If the user provides only a run ID, detect the repository from the local git remote rather than asking.
- **Handle missing artifacts gracefully.** The `workflow-failures-summary` artifact may not exist if the summary job was skipped or if only non-clippier jobs failed. Fall back to per-job log inspection.

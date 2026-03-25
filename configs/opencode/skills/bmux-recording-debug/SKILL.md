---
name: bmux-recording-debug
description: Investigate bmux terminal recordings to reconstruct user actions and isolate failure points. Interactive — narrows timelines, validates expected event chains, and produces evidence-ready findings.
allowed-tools: Bash(cargo:*), Bash(ls:*), Bash(rg:*), Bash(python3:*), Bash(jq:*), Question(*)
---

## Purpose

Use bmux recordings to debug behavior regressions by reconstructing what happened on the timeline, separating signal from polling noise, and validating whether expected request and server-event chains completed. This skill is optimized for incident triage and bug reproduction analysis (for example: split pane -> create window/context -> switch back failure).

## Prerequisites

- Run from the bmux repository root so `cargo run -p bmux_cli -- ...` works.
- The target machine must have access to bmux runtime recordings.

## Steps

### 1. Resolve the recording target

If the user already provided a recording ID, use it directly. Otherwise discover candidates:

```bash
cargo run -p bmux_cli -- recording list --json
```

Parse and present top candidates by recency and size:

```bash
cargo run -p bmux_cli -- recording list --json | jq -r '.recordings[] | [.id, .started_at, .event_count, .payload_bytes] | @tsv'
```

If multiple candidates could match the repro, ask the user which one to inspect before continuing.

### 2. Build a quick timeline skeleton

Inspect early events to identify protocol shape and establish sequence context:

```bash
cargo run -p bmux_cli -- recording inspect <recording-id> --json --limit 400
```

Capture the user-expected flow in one line (example: `split pane -> create context -> reattach -> select previous context`).

Treat this as the expected chain to validate in later steps.

### 3. Find anchor events fast

Locate the raw event file path:

```bash
ls "$HOME/Library/Application Support/bmux/State/runtime/recordings/<recording-id>"
```

Use `rg` to find first-pass anchors in `events.jsonl` (request names and key server events):

```bash
rg -n '"split_pane"|"create_context"|"attach_context"|"select_context"|"client_attached"|"client_detached"' "$HOME/Library/Application Support/bmux/State/runtime/recordings/<recording-id>/events.jsonl"
```

Record candidate sequence numbers for each action stage.

### 4. Reduce noise and extract a high-signal stream

Most recordings are dominated by `poll_events`. Filter to high-value event kinds:

- `request_start`
- `request_done`
- `server_event`
- `pane_input_raw` (when present)

Generate a compact event stream with Python:

```bash
python3 - <<'PY'
import json
from pathlib import Path

rid = "<recording-id>"
path = Path.home() / "Library/Application Support/bmux/State/runtime/recordings" / rid / "events.jsonl"
keep = {"request_start", "request_done", "server_event", "pane_input_raw"}

for line in path.open():
    evt = json.loads(line)
    k = evt.get("kind")
    if k not in keep:
        continue
    seq = evt.get("seq")
    ts = evt.get("ts")
    req = evt.get("request") or evt.get("name") or ""
    out = evt.get("outcome") or evt.get("event") or ""
    print(f"{seq}\t{ts}\t{k}\t{req}\t{out}")
PY
```

If output volume is still high, narrow to request names related to the repro.

### 5. Validate critical transitions

For each user action, verify the expected request/event chain:

1. `request_start` for the action
2. matching `request_done` with success outcome
3. related `server_event` transitions (for context/window changes, especially `client_detached` and `client_attached`)

For context switch issues, confirm whether `select_context` resolves to the expected session/context IDs and whether attach lifecycle events follow.

When IDs differ from expectation, flag the first diverging sequence as the likely failure point.

### 6. Produce evidence-ready findings

Report findings in this format:

```text
Recording: <id>
Expected flow: <one-line chain>
Observed anchors:
- <action> at seq <n> ... <result>
- <action> at seq <n> ... <result>
First divergence:
- seq <n>: <why it diverges>
Confidence:
- <high|medium|low> (<short reason>)
Suggested next probe:
- <exact command and why>
```

Include exact sequence numbers and IDs (session/context/client) whenever available.

### 7. Optional deep-dive loop

If root cause is still unclear, iterate with one focused refinement at a time:

- tighter seq window around divergence
- include `pane_output_raw` only near the suspect window
- compare expected and observed ID transitions side-by-side

After each refinement, restate whether the failure appears client-side request handling, server state transition, or attach synchronization.

## Worked example (reference)

Recording `1234394d-01c4-4e3a-96d5-adb2e8c47b46` produced these useful anchors during prior analysis:

- `split_pane`: request start around `seq 441670`, done around `seq 441672`
- context creation/attach transition around `seq 604476` to `seq 604484`
- later context switch attempt (`select_context`) around `seq 3570886` to `seq 3570889`

Use these as landmarks when validating repros with similar flow (`split -> new context/window -> switch back`).

## Rules

- **Confirm the target recording before deep analysis.** If candidate recordings are ambiguous, ask the user to choose one instead of guessing.
- **Filter before interpreting.** Never draw conclusions from raw unfiltered streams dominated by `poll_events`.
- **Anchor every claim to seq numbers.** Findings must cite exact sequence IDs and relevant request/event names.
- **Differentiate expected vs observed chains.** Always state both so the first divergence is explicit.
- **One refinement at a time.** In deep dives, change only one filter/window dimension per iteration to avoid mixed signals.
- **No fabrication.** If an event is missing or unclear, state uncertainty and propose the next concrete probe command.

---
name: bmux-perf-analyze
description: Analyze bmux recording performance telemetry and produce actionable troubleshooting guidance. Read-only - prints findings and next steps for you to apply.
allowed-tools: Bash(bmux:*), Bash(jq:*)
---

## Purpose

Analyze a bmux recording's `bmux.perf` telemetry and convert raw metrics into an actionable troubleshooting summary. This skill is diagnostics-only: it does not modify files, change config, toggle runtime settings, or make code edits.

## Prerequisites

- `bmux` is installed and accessible in PATH.
- The target recording exists.
- The recording captures `custom` events (required for perf telemetry).

## Steps

### 1. Run perf analysis in JSON mode

Run:

```bash
bmux recording analyze <recording-id> --perf --json
```

If the command fails, return the error and stop.

### 2. Extract core signals

Use `jq` to extract the minimum diagnostics surface:

```bash
bmux recording analyze <recording-id> --perf --json | jq '{
  perf_events,
  malformed_payloads,
  dropped_events_reported,
  dropped_payload_bytes_reported,
  connect_to_first_frame_ms,
  connect_to_interactive_ms,
  reconnect_outage_max_ms,
  render_p95_ms: .timings_ms.render_ms_max.p95_ms,
  drain_ipc_p95_ms: .timings_ms.drain_ipc_ms_max.p95_ms,
  hints,
  outlier_samples
}'
```

Also review event coverage and level mix:

```bash
bmux recording analyze <recording-id> --perf --json | jq '{by_event_name, by_level, span_ms}'
```

### 3. Classify bottlenecks

Classify findings into these buckets:

- **Telemetry quality risk**
  - `perf_events == 0`
  - `malformed_payloads > 0`
  - `dropped_events_reported > 0` or `dropped_payload_bytes_reported > 0`
- **Startup/connect path risk**
  - `connect_to_interactive_ms > 1500`
- **Reconnect/network risk**
  - `reconnect_outage_max_ms > 1000`
- **Render path risk**
  - `render_p95_ms > 16`
- **IPC drain/backpressure risk**
  - `drain_ipc_p95_ms > 20`

Use `outlier_samples` to identify top event+metric offenders that support the classification.

### 4. Produce actionable recommendations

Output recommendations in priority order:

1. **Capture quality actions first** (if telemetry quality is weak).
2. **Most likely bottleneck class** with evidence values.
3. **Targeted next checks** tied to observed outliers/metrics.
4. **Confidence level** (`high`, `medium`, `low`) based on data completeness.

When capture quality is weak, recommend explicit recapture steps as instructions (not actions to execute), for example:

- ensure recording includes `custom` events
- use a higher perf profile for next capture
- increase perf rate limits if drops were reported

### 5. Print a concise troubleshooting report

Use this output structure:

- Recording analyzed
- Data quality summary
- Top bottlenecks (ordered)
- Evidence (key metrics + notable outliers)
- Recommended next actions (numbered)
- Confidence level

Keep the report concise and evidence-backed.

## Rules

- **Read-only only.** Never run mutating actions (no file edits, no config writes, no `bmux perf on/off`, no commits).
- **Evidence-bound conclusions.** Every diagnosis must cite concrete report fields and values.
- **Quality-first triage.** If telemetry quality is insufficient, prioritize recapture guidance before deeper claims.
- **No fabricated details.** If a field is missing or null, say so explicitly.
- **Actionable output.** Recommendations must be specific and directly tied to observed signals.
- **Respect user scope.** Analyze only the recording(s) the user requested.

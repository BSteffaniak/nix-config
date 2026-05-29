---
name: bcode-session-history
description: Browse, search, understand, and troubleshoot Bcode session history from the local Bcode state directory. Use this to list sessions, inspect event timelines, export JSONL, diagnose corrupt indexes/logs, inspect trace artifacts, and understand imported pi/opencode sessions.
---

## Purpose

Use this skill when the user asks to find, recall, inspect, search, export, or troubleshoot Bcode sessions. Bcode stores canonical session history as append-only binary event logs under the Bcode state directory, with sidecar indexes and trace artifacts. Prefer Bcode CLI/API commands over ad-hoc parsing.

Use this for requests like:

- "find my previous Bcode session about X"
- "what did we do in that session?"
- "why won't this session load?"
- "diagnose/reindex/repair session history"
- "inspect the tool calls, permissions, runtime work, or traces for a session"

## Storage Reference

### State directory

Bcode's default state directory is resolved in this order:

1. `$BCODE_STATE_DIR`
2. `$XDG_STATE_HOME/bcode`
3. `~/.local/state/bcode`

Important subdirectories:

```text
<state-dir>/sessions/     # canonical session event logs + derived indexes
<state-dir>/traces/       # trace blob artifacts referenced by TraceEvent/tool outputs
<state-dir>/daemons/      # daemon metadata and log paths
<state-dir>/logs/         # daemon/runtime logs when configured there
```

### Session files

Canonical session event logs are stored as:

```text
<state-dir>/sessions/<session-id>.events
```

These are **binary framed append-only event logs**, not JSONL. Do not hand-parse them with JSON tools. Use Bcode commands to read, export, diagnose, reindex, or repair them.

Sidecar/index data may exist next to the logs. Treat indexes as derived state: if they are stale or corrupt, rebuild them from canonical `.events` logs.

## Operations

### 1. List sessions

Start here when the user does not know the session ID:

```bash
bcode session list
```

Output includes the display name, session ID, and connected client count. Always preserve the session ID for follow-up commands.

### 2. Read a session's event history

```bash
bcode session history <session-id>
```

This prints a readable event stream. Use it to understand user messages, assistant messages, tool calls, permissions, model changes, agent changes, and other durable events.

### 3. Export a session as JSONL

Use export when you need machine-readable output, `jq`, grep, or scripted analysis:

```bash
bcode session export <session-id> --format jsonl
```

Example focused search inside one session:

```bash
bcode session export <session-id> --format jsonl | grep -i 'keyword'
```

For full fidelity, prefer exported JSONL over the human-readable `history` command.

### 4. View a compact timeline

```bash
bcode session timeline <session-id>
```

Use this for troubleshooting turn order, trace timing, runtime work, tool activity, or long sessions where full history is noisy.

### 5. Diagnose a session

```bash
bcode session diagnose <session-id>
bcode session diagnose <session-id> --json
```

Use JSON mode when you need exact event counts, latest event kinds, trace payloads, or structured troubleshooting output.

### 6. Doctor session storage

```bash
bcode session doctor
bcode session doctor <session-id>
bcode session doctor --json
```

Use doctor when the user reports missing sessions, unreadable history, schema/index problems, or broken session loading.

### 7. Rebuild derived indexes

Indexes are derived from canonical event logs. If list/history/diagnose suggests stale or corrupt index data, reindex:

```bash
bcode session reindex
bcode session reindex <session-id>
```

Reindexing should not rewrite canonical session events.

### 8. Repair an unreadable event-log tail

If a session has a corrupt or truncated tail, use the official repair command:

```bash
bcode session repair <session-id>
```

This repairs unreadable tail data and backs up the original log. Do not manually edit `.events` files.

### 9. Inspect runtime work

Runtime work captures durable long-running operations such as tool/plugin/service work:

```bash
bcode runtime-work list <session-id>
bcode runtime-work history <session-id> --limit 100
```

Use this when a turn appears stuck, cancelled, partially completed, or tool/plugin behavior needs reconstruction.

## Searching Across Sessions

Because canonical `.events` files are binary, do **not** rely on raw `grep` over `*.events` except as rough last-resort triage. Prefer exporting candidate sessions and searching the JSONL.

Typical workflow:

1. Run `bcode session list`.
2. Identify candidate sessions by name/recency.
3. Export each candidate:

   ```bash
   bcode session export <session-id> --format jsonl
   ```

4. Search exported JSONL with `grep`, `jq`, or a small script.
5. Use `history`, `timeline`, or `diagnose --json` on the best match.

If many sessions must be searched, write a temporary script that collects IDs from `bcode session list`, exports each session, and searches exported JSON. Keep it read-only.

## Event Model Reference

Common durable event kinds to recognize:

- `SessionCreated` — session start, optional name, working directory.
- `SessionRenamed` — display name changed.
- `ClientAttached` / `ClientDetached` — TUI/CLI clients connected or disconnected.
- `UserMessage` — user-authored input.
- `AssistantDelta` / `AssistantMessage` — assistant response content.
- `AssistantReasoningDelta` / `AssistantReasoningMessage` — provider-exposed reasoning content if available.
- `ToolCallRequested` — tool name and JSON arguments.
- `ToolCallFinished` — tool result, error flag, optional trace artifact reference.
- `ToolInvocationStream` — incremental tool events while a tool runs.
- `PermissionRequested` / `PermissionResolved` — permission gate lifecycle.
- `ModelChanged` — active provider/model changed.
- `AgentChanged` — active agent changed.
- `SystemMessage` — durable system/status message.
- `ModelTurnStarted` / `ModelTurnFinished` / `ModelUsage` — model turn lifecycle and usage.
- `ModelTurnCancelRequested` — cancellation requested for a turn.
- `ContextCompacted` — context summarized/compacted through a sequence number.
- `TraceEvent` — structured trace payload, often with timing and provider/tool details.
- `SkillInvoked` / `SkillSuggested` / `SkillActivated` / `SkillDeactivated` / `SkillContextLoaded` / `SkillInvocationFailed` — skill lifecycle events.
- `RuntimeWorkStarted` / `RuntimeWorkProgress` / `RuntimeWorkCancelRequested` / `RuntimeWorkFinished` — durable runtime work lifecycle.
- `WorkingDirectoryChanged` — canonical working directory moved.
- `SessionImported` — session was imported from another agent/source such as `pi` or `opencode`.

## Troubleshooting Playbooks

### Session not listed

1. Check the active state directory:
   ```bash
   echo "${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
   ```
2. List session files:
   ```bash
   ls -la "${BCODE_STATE_DIR:-$HOME/.local/state/bcode}/sessions"
   ```
3. Run:
   ```bash
   bcode session doctor --json
   bcode session reindex
   ```
4. If using a daemon, verify daemon status/logs before assuming data is gone.

### Session history fails to load

1. Run:
   ```bash
   bcode session diagnose <session-id> --json
   ```
2. If the issue points at indexes, run:
   ```bash
   bcode session reindex <session-id>
   ```
3. If the issue points at an unreadable/truncated event tail, run:
   ```bash
   bcode session repair <session-id>
   ```
4. Re-run `diagnose` and then `history`.

### Need to understand what happened in a long session

1. Run `bcode session timeline <session-id>` for a compact overview.
2. Run `bcode session export <session-id> --format jsonl` for structured search.
3. Identify key sequences around user messages, tool calls, permission decisions, runtime work, and trace events.
4. Use `history` for human-readable reconstruction.

### Need to troubleshoot tool/plugin behavior

1. Search for `ToolCallRequested`, `ToolCallFinished`, and `ToolInvocationStream` events.
2. Check `is_error`, `result`, arguments JSON, and any artifact path.
3. Inspect `TraceEvent` payloads and trace blob references under `<state-dir>/traces/` if needed.
4. Check runtime work history:
   ```bash
   bcode runtime-work history <session-id> --limit 100
   ```

### Need to identify imported sessions

Look for `SessionImported` in exported JSONL or human-readable history. It includes:

- `source_id` such as `pi` or `opencode`
- `source_display_name`
- `external_session_id`
- `imported_at_ms`

Use source-specific skills, such as `pi-session-history` or `opencode-session-history`, when the user needs to inspect the original external session source.

## Output Guidelines

- Always show session IDs in results.
- Prefer a short summary first; provide full event/export details only when useful or requested.
- Clearly distinguish user messages, assistant messages, tool calls, permissions, runtime work, trace events, and system/status events.
- For searches, state what was searched and what was skipped.
- For troubleshooting, report the exact commands run and the observed result.
- If nothing is found, say so plainly; never fabricate session content or paths.

## Rules

- **Read-only by default.** Do not modify session state unless the user explicitly asks to repair/reindex, or the operation is clearly diagnostic and official (`bcode session reindex`, `doctor --fix`, `repair`).
- **Do not manually edit `.events` files.** They are binary canonical logs.
- **Do not manually delete indexes or traces** unless the user explicitly asks and understands the consequence.
- **Use Bcode commands before raw filesystem parsing.** The CLI knows the event schema and framing.
- **Treat indexes as derived and event logs as canonical.** Rebuild indexes instead of trusting stale sidecars.
- **Preserve evidence.** If repairing, mention backup paths produced by Bcode.

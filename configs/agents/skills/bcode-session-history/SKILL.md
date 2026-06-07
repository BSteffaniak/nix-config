---
name: bcode-session-history
description: Browse, search, understand, and troubleshoot Bcode session history from the local Bcode session databases. Use this to list sessions, inspect event timelines, export JSONL, query read-only DB tables, inspect trace artifacts, and understand imported pi/opencode sessions.
---

## Purpose

Use this skill when the user asks to find, recall, inspect, search, export, or troubleshoot Bcode sessions. Bcode stores session history in a DB-backed architecture under the Bcode state directory. Prefer Bcode CLI/API commands first, then use read-only database queries for focused inspection when useful.

Use this for requests like:

- "find my previous Bcode session about X"
- "what did we do in that session?"
- "why won't this session load?"
- "inspect the tool calls, permissions, runtime work, or traces for a session"
- "search Bcode sessions for a keyword"

## Storage Reference

### State directory

Bcode's default state directory is resolved in this order:

1. `$BCODE_STATE_DIR`
2. `$XDG_STATE_HOME/bcode`
3. `~/.local/state/bcode`

Helpful shell variable:

```bash
STATE="${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
```

Important paths:

```text
<state-dir>/sessions/catalog.db                 # global session catalog database
<state-dir>/sessions/<session-id>/session.db    # per-session event/projection database
<state-dir>/traces/                             # trace blob artifacts referenced by trace/tool events
<state-dir>/daemons/                            # daemon metadata and log paths
<state-dir>/logs/                               # daemon/runtime logs when configured there
```

### Database model

Bcode uses one global catalog database plus one database per session.

#### Global catalog: `<state-dir>/sessions/catalog.db`

Primary table:

| Table      | Purpose                                                                                                              |
| ---------- | -------------------------------------------------------------------------------------------------------------------- |
| `sessions` | One row per known session, including title, working directory, activity time, DB path, state, and projection status. |

Useful `sessions` columns:

- `session_id`
- `db_path`
- `title`
- `working_directory`
- `created_at_ms`
- `updated_at_ms`
- `state`
- `projection_status`

#### Per-session DB: `<state-dir>/sessions/<session-id>/session.db`

Useful tables:

| Table                    | Purpose                                                                                |
| ------------------------ | -------------------------------------------------------------------------------------- |
| `events`                 | Durable event stream rows with sequence, type, timestamps, and JSON payload.           |
| `session_state`          | Current projected session state such as title, working directory, model, and provider. |
| `input_messages`         | User input history projection.                                                         |
| `transcript`             | Conversation/transcript projection.                                                    |
| `tool_runs`              | Tool invocation lifecycle projection.                                                  |
| `runtime_work`           | Runtime work lifecycle projection.                                                     |
| `projection_checkpoints` | Projection progress/checkpoint metadata.                                               |
| `snapshots`              | Stored projection snapshots.                                                           |

The `events.payload` column is JSON text for the durable event. Projection tables are optimized views for browsing, searching, and diagnostics.

## Operations

### 1. List sessions

Start here when the user does not know the session ID:

```bash
bcode session list
```

Output includes the display name, session ID, and connected client count. Always preserve the session ID for follow-up commands.

Read-only DB alternative:

```bash
STATE="${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
sqlite3 "$STATE/sessions/catalog.db" \
  "select session_id, coalesce(title, ''), working_directory, datetime(updated_at_ms/1000, 'unixepoch') from sessions order by updated_at_ms desc limit 20;"
```

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

Use JSON mode when you need exact event counts, latest event kinds, trace payloads, or scriptable output.

### 6. Inspect session DB tables read-only

Set the paths:

```bash
STATE="${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
SESSION_ID="<session-id>"
SESSION_DB="$STATE/sessions/$SESSION_ID/session.db"
```

List tables:

```bash
sqlite3 "$SESSION_DB" ".tables"
```

Inspect event sequence and types:

```bash
sqlite3 "$SESSION_DB" \
  "select event_seq, event_type, datetime(created_at_ms/1000, 'unixepoch') from events order by event_seq limit 100;"
```

Search durable event payloads:

```bash
sqlite3 "$SESSION_DB" \
  "select event_seq, event_type, substr(payload, 1, 300) from events where payload like '%keyword%' order by event_seq;"
```

Inspect transcript rows:

```bash
sqlite3 "$SESSION_DB" \
  "select * from transcript order by event_seq_start limit 100;"
```

Inspect user input history:

```bash
sqlite3 "$SESSION_DB" \
  "select input_seq, event_seq, datetime(created_at_ms/1000, 'unixepoch'), substr(text, 1, 300) from input_messages order by input_seq desc limit 50;"
```

Inspect tool runs:

```bash
sqlite3 "$SESSION_DB" \
  "select tool_call_id, event_seq_start, event_seq_end, status, tool_name, is_error from tool_runs order by event_seq_start desc limit 50;"
```

Inspect runtime work:

```bash
sqlite3 "$SESSION_DB" \
  "select work_id, event_seq_start, event_seq_end, kind, label, status, parent_work_id, datetime(started_at_ms/1000, 'unixepoch'), datetime(finished_at_ms/1000, 'unixepoch'), message from runtime_work order by event_seq_start desc limit 50;"
```

## Searching Across Sessions

Prefer the CLI when a session is known. For broad search, query the catalog first, then inspect likely session DBs.

List recent session DB paths:

```bash
STATE="${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
sqlite3 "$STATE/sessions/catalog.db" \
  "select session_id, db_path, coalesce(title, ''), working_directory from sessions order by updated_at_ms desc limit 50;"
```

Search durable payloads across all session DBs:

```bash
STATE="${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
KEYWORD="keyword"
find "$STATE/sessions" -name session.db -print0 | while IFS= read -r -d '' db; do
  session_id="$(basename "$(dirname "$db")")"
  sqlite3 "$db" "select '$session_id', event_seq, event_type, substr(payload, 1, 240) from events where payload like '%$KEYWORD%' order by event_seq limit 10;"
done
```

For exact JSON matching, export a specific session and use `jq` after identifying candidate session IDs.

## Common Event Types

You may see these event types in `events.event_type`, CLI history, timeline, or exported JSONL:

- `SessionCreated` — session initialized.
- `UserMessage` — user-authored prompt/input.
- `AssistantMessage` / `AssistantMessageDelta` — assistant response content.
- `AssistantReasoningDelta` — provider reasoning content.
- `ToolCallRequested` / `ToolCallFinished` / `ToolInvocationStream` — tool lifecycle and streamed output.
- `PermissionRequested` / `PermissionResolved` — permission flow.
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
2. Check the catalog DB exists:
   ```bash
   STATE="${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
   ls -la "$STATE/sessions/catalog.db"
   ```
3. Query the catalog directly:
   ```bash
   sqlite3 "$STATE/sessions/catalog.db" \
     "select session_id, coalesce(title, ''), state, projection_status, datetime(updated_at_ms/1000, 'unixepoch') from sessions order by updated_at_ms desc limit 50;"
   ```
4. Verify daemon status/logs before assuming data is gone:
   ```bash
   bcode server status --verbose
   ```

### Session history fails to load

1. Run:
   ```bash
   bcode session diagnose <session-id> --json
   ```
2. Confirm the per-session DB exists:
   ```bash
   STATE="${BCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bcode}"
   ls -la "$STATE/sessions/<session-id>/session.db"
   ```
3. Inspect core tables read-only:
   ```bash
   sqlite3 "$STATE/sessions/<session-id>/session.db" ".tables"
   sqlite3 "$STATE/sessions/<session-id>/session.db" \
     "select count(*), min(event_seq), max(event_seq) from events;"
   sqlite3 "$STATE/sessions/<session-id>/session.db" \
     "select * from session_state;"
   ```
4. Check daemon logs if the CLI/API path is failing.

### Need to understand what happened in a long session

1. Run `bcode session timeline <session-id>` for a compact overview.
2. Run `bcode session export <session-id> --format jsonl` for structured search.
3. Identify key sequences around user messages, tool calls, permission decisions, runtime work, and trace events.
4. Use `history` for human-readable reconstruction.
5. Use read-only DB queries against `transcript`, `tool_runs`, and `runtime_work` for focused inspection.

### Need to troubleshoot tool/plugin behavior

1. Search for `ToolCallRequested`, `ToolCallFinished`, and `ToolInvocationStream` events.
2. Inspect `tool_runs` for status, tool name, sequence range, and error status.
3. Check event payload JSON for arguments, results, and artifact paths.
4. Inspect `TraceEvent` payloads and trace blob references under `<state-dir>/traces/` if needed.
5. Check runtime work history:
   ```bash
   bcode runtime-work history <session-id> --limit 100
   ```

### Need to identify imported sessions

Look for `SessionImported` in exported JSONL, human-readable history, or event payloads. It includes:

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

- **Read-only by default.** Do not modify session state unless the user explicitly asks for a supported mutating operation.
- **Prefer Bcode commands before raw database queries.** The CLI/API knows the event schema and product semantics.
- **Use read-only SQL inspection only.** Do not run `insert`, `update`, `delete`, `drop`, `alter`, `vacuum`, or other mutating database commands.
- **Do not manually edit session databases, traces, daemon metadata, or logs.**
- **Preserve evidence.** When troubleshooting, record the exact command/query used and the observed result.

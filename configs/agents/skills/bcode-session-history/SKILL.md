---
name: bcode-session-history
description: Browse, search, understand, export, and troubleshoot Bcode session history through supported bounded Bcode CLI operations without opening canonical databases directly.
---

## Purpose

Use this skill when the user asks to find, recall, inspect, search, export, or troubleshoot native Bcode sessions.

Canonical session storage is daemon-owned. Use only supported `bcode session ...` and related Bcode commands. Never open or query catalog/session databases, WAL files, private sidecars, or search-provider files directly. Use a source-specific history skill only when the user asks to inspect an imported session in its original external source.

## Standard workflow

### 1. List candidate sessions

```sh
bcode session list --json
```

Keep candidate sets bounded and preserve session IDs in notes and output.

### 2. Inspect bounded canonical history

```sh
bcode session history SESSION_ID --limit 100 --json
bcode session around SESSION_ID SEQUENCE --before 20 --after 20 --json
bcode session inspect SESSION_ID failed-tool-calls --limit 50 --json
```

Use the appropriate supported `session inspect` category for permissions, model/agent changes, runtime work, compaction, and terminal outcomes. Follow returned cursors for additional bounded pages. Do not substitute raw storage access when Bcode reports damaged, stale, future-version, ambiguous, or repair-required state.

### 3. Search optional derived providers

```sh
bcode session search 'database locked' --json --hydrate
bcode session search 'permission denied' --match phrase --content tool-error --json
bcode session search 'exit status' --content shell-command --content tool-error \
  --tool-status failed --json
bcode session search 'migration' --working-directory /workspace/project \
  --after-timestamp-ms 1767225600000 --before-timestamp-ms 1769817600000 --json
```

Use `--deep` only for explicitly requested expensive or cold content. Explain selection first when scope or cost is uncertain:

```sh
bcode session search-explain 'segmentation fault' --content shell-output --deep --json
```

Search is optional derived state. If no provider is eligible or available, continue with canonical list/history/around/inspect operations. Never claim shell/tool-output coverage merely because deep mode was accepted; inspect provider coverage in the response.

### 4. Export only when complete history is required

```sh
bcode session export SESSION_ID --format jsonl
```

Export is an explicit potentially full-history operation. Prefer bounded commands for normal investigation.

### 5. Use explicit search maintenance only when requested

```sh
bcode session search-status --json
bcode session search-explain QUERY --json
bcode session search-backfill-start --provider PROVIDER_ID --session SESSION_ID --json
bcode session search-backfill-status OPERATION_ID --json
bcode session search-backfill-wait OPERATION_ID --after-revision REVISION --json
bcode session search-backfill-cancel OPERATION_ID --json
```

Operation identity and status are daemon-memory state, not durable resume. Disconnect or daemon restart can lose operation visibility. Provider-owned checkpoints can let a newly requested backfill continue safely, but do not imply reconnect-safe replay or durable transport resume.

Rebuild and purge affect only disposable provider-owned state and require exact confirmation. Run them only when explicitly requested after reviewing status:

```sh
bcode session search-rebuild --provider PROVIDER_ID --confirm CONFIRMATION --json
bcode session search-purge --provider PROVIDER_ID --confirm CONFIRMATION --json
```

## Troubleshooting

- If a session does not appear, use `bcode session list --json` and report catalog state exactly as returned.
- If history fails, use `bcode session diagnose SESSION_ID --json` and supported `session doctor` commands. Never inspect database or WAL files manually.
- Report no-provider, no-results, timeout, stale-index, incomplete-coverage, or unsupported-query outcomes and fall back to bounded canonical inspection where possible.
- Report stale locators rather than guessing replacements.
- Use supported runtime-work and trace/artifact commands; do not crawl state directories.
- For an imported session's original history, use its source-specific skill. Native Bcode investigation still uses canonical Bcode commands only.

## Required output

Always include:

- canonical session ID(s);
- query and structured-filter scope;
- ordinary or deep mode;
- providers selected/searched and each provider outcome;
- content categories searched and skipped;
- freshness/checkpoint or stale/degraded state reported by Bcode;
- truncation, pagination, and hydration state;
- timeout or cancellation state;
- failures, unsupported capabilities, and incomplete coverage;
- exact supported commands run when troubleshooting.

Start with a concise summary. Distinguish canonical events from derived search hits and provider previews. If nothing is found, say so plainly and describe the bounded scope searched.

## Rules

- Read-only by default. Run supported mutating maintenance only when explicitly requested.
- Never use SQL or open canonical database files, WAL files, sidecars, or provider indexes.
- Never edit session, trace, daemon, log, checkpoint, or provider files manually.
- Never represent provider checkpoints or operation snapshots as durable transport resume.
- Preserve evidence by recording supported commands and observed outcomes.

---
name: pi-session-history
description: Browse and search pi conversation history from JSONL session files in ~/.pi/agent/sessions/. List sessions, read past conversations, extract just the user prompts to triage what a session was about, and search across sessions by keyword. Use this when the user asks you to find or recall a previous pi session.
---

## Purpose

Read pi's on-disk session log to recall what was discussed, what tools ran, and which files were touched in past conversations. Pi stores every session as a JSONL file under `~/.pi/agent/sessions/`, organized by working directory. There is no database — each line is a JSON entry, and the first line is a header with the session `cwd`.

Use this skill whenever the user asks you to "find a session", "look up what we did", "search my pi history", or similar.

## File Layout

```
~/.pi/agent/sessions/
  --<path-with-slashes-as-dashes>--/
    <ISO-timestamp>_<uuid>.jsonl
    <ISO-timestamp>_<uuid>/                # subagent fan-out runs (filter out by default)
      <hash>/run-<N>/session.jsonl
```

The directory name encodes the `cwd` (slashes → dashes, wrapped in `--`). **Do not parse it** — read the first line of the JSONL and use the `cwd` field instead. It's authoritative.

## JSONL Schema (only what matters for reading)

Every line is a JSON object with a `type`:

- **`session`** (always first line) — header. Keys: `version`, `id`, `timestamp` (ISO string), `cwd`, optional `parentSession`.
- **`message`** — one conversational turn. Keys: `id`, `parentId`, `timestamp` (ISO), `message: { role, content, ... }`.
  - `role`: `user` | `assistant` | `toolResult` | `bashExecution` | `custom` | `branchSummary` | `compactionSummary`
  - `content`: for `user` it can be a **string OR an array of `{type:"text"|"image", ...}`**. For `assistant` it's an array of `{type:"text"|"thinking"|"toolCall", ...}`. For `toolResult` it's an array of `{type:"text"|"image", ...}`.
- **`session_info`** — user-set display name (`name` field).
- **`compaction`**, **`model_change`**, **`thinking_level_change`**, **`branch_summary`**, **`custom`**, **`custom_message`**, **`label`** — usually skip when summarizing for the user.

Important quirks:

- Timestamps are **ISO 8601 strings**, not epoch ms.
- `thinking` content blocks contain large encrypted reasoning blobs — always skip them in human-facing output.
- Tree structure (id/parentId) means entries aren't strictly linear, but for read-only browsing, file order is fine.

## Operations

### 1. List recent sessions

Default: 20 most recently modified top-level session files across all projects. Filter out nested `*/run-*/session.jsonl` subagent fan-out files unless the user asks for them.

```bash
python3 - <<'PY'
import os, json, glob
from datetime import datetime

ROOT = os.path.expanduser('~/.pi/agent/sessions')
# Top-level only: <root>/<dir>/<file>.jsonl
files = []
for d in os.listdir(ROOT):
    full = os.path.join(ROOT, d)
    if not os.path.isdir(full): continue
    for f in glob.glob(os.path.join(full, '*.jsonl')):
        files.append(f)

files.sort(key=os.path.getmtime, reverse=True)
for f in files[:20]:
    cwd, name = '?', ''
    try:
        with open(f) as fh:
            hdr = json.loads(fh.readline())
            cwd = hdr.get('cwd', '?')
        # session_info entries (user-set name) appear later — scan if cheap
        with open(f) as fh:
            for line in fh:
                try: o = json.loads(line)
                except: continue
                if o.get('type') == 'session_info':
                    name = o.get('name', '')
    except Exception as e:
        cwd = f'(error: {e})'
    mtime = datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M')
    print(f'{mtime}  {cwd}')
    if name: print(f'           name: {name}')
    print(f'           {f}')
    print()
PY
```

To filter by project directory, narrow with the encoded directory name **or** post-filter on the header `cwd`:

```bash
# Post-filter on cwd (more reliable, handles symlinks etc.)
python3 - <<'PY'
import os, json, glob
from datetime import datetime
NEEDLE = 'git-sshripped'   # substring match against cwd
ROOT = os.path.expanduser('~/.pi/agent/sessions')
hits = []
for d in os.listdir(ROOT):
    full = os.path.join(ROOT, d)
    if not os.path.isdir(full): continue
    for f in glob.glob(os.path.join(full, '*.jsonl')):
        try:
            with open(f) as fh:
                cwd = json.loads(fh.readline()).get('cwd', '')
            if NEEDLE in cwd:
                hits.append((f, cwd))
        except Exception: pass
hits.sort(key=lambda x: os.path.getmtime(x[0]), reverse=True)
for f, cwd in hits[:20]:
    mtime = datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M')
    print(f'{mtime}  {cwd}')
    print(f'           {f}\n')
PY
```

### 2. Read a session's conversation

Print messages chronologically. Skip `thinking` blocks. Truncate long content in the default view; only show full content when the user asks.

```bash
python3 - <<'PY'
import json, sys
from datetime import datetime

PATH = '/path/to/session.jsonl'   # replace
TRUNC = 400                        # chars per content block

def render_content(c):
    if isinstance(c, str):
        return c
    out = []
    for block in c or []:
        t = block.get('type')
        if t == 'text':
            out.append(block.get('text', ''))
        elif t == 'thinking':
            out.append('[thinking …]')   # skip the encrypted blob
        elif t == 'toolCall':
            args = json.dumps(block.get('arguments', {}))[:200]
            out.append(f'-> {block.get("name")}({args})')
        elif t == 'image':
            out.append('[image]')
    return '\n'.join(out)

with open(PATH) as fh:
    for line in fh:
        try: o = json.loads(line)
        except: continue
        ty = o.get('type')
        if ty == 'session':
            print(f'== session {o.get("id")} cwd={o.get("cwd")} ==\n')
            continue
        if ty != 'message':
            continue
        m = o.get('message', {})
        role = m.get('role', '?')
        ts = o.get('timestamp', '')[:19].replace('T', ' ')
        body = render_content(m.get('content'))
        body = (body or '').strip().replace('\n', ' ⏎ ')
        if len(body) > TRUNC: body = body[:TRUNC] + '…'
        if role == 'toolResult':
            tn = m.get('toolName', '?')
            print(f'[{ts}] tool({tn}): {body}')
        else:
            print(f'[{ts}] {role}: {body}')
PY
```

For full untruncated output, raise `TRUNC` or remove the truncation.

### 3. Extract user prompts only

The fastest way to figure out what a session was about. Lists every user-authored prompt with its timestamp.

```bash
python3 - <<'PY'
import json
PATH = '/path/to/session.jsonl'   # replace
with open(PATH) as fh:
    n = 0
    for line in fh:
        try: o = json.loads(line)
        except: continue
        if o.get('type') != 'message': continue
        m = o.get('message', {})
        if m.get('role') != 'user': continue
        c = m.get('content')
        if isinstance(c, list):
            text = '\n'.join(b.get('text', '') for b in c if b.get('type') == 'text').strip()
        else:
            text = (c or '').strip()
        if not text or text.startswith('<'):   # skip system/tool reinjections
            continue
        ts = o.get('timestamp', '')
        print(f'[{n}] {ts}')
        print(f'    {text[:600]}\n')
        n += 1
PY
```

Use this first when the user describes a session by what _they_ said in it — it cuts past tool noise and assistant chatter.

### 4. Search across sessions

Grep a keyword across every JSONL, return matching session files plus the first user prompt as context.

```bash
python3 - <<'PY'
import os, json, glob, re
NEEDLE = re.compile(r'reencrypt|re-encrypt|file rename', re.IGNORECASE)
CWD_FILTER = ''   # optional: substring match on session header cwd
ROOT = os.path.expanduser('~/.pi/agent/sessions')

def first_user_prompt(path):
    with open(path) as fh:
        for line in fh:
            try: o = json.loads(line)
            except: continue
            if o.get('type') != 'message': continue
            m = o.get('message', {})
            if m.get('role') != 'user': continue
            c = m.get('content')
            t = ('\n'.join(b.get('text','') for b in c if b.get('type')=='text')
                 if isinstance(c, list) else (c or ''))
            t = t.strip()
            if t and not t.startswith('<'): return t
    return ''

hits = []
for d in os.listdir(ROOT):
    full = os.path.join(ROOT, d)
    if not os.path.isdir(full): continue
    for f in glob.glob(os.path.join(full, '*.jsonl')):
        try:
            with open(f) as fh:
                first = fh.readline()
                cwd = json.loads(first).get('cwd', '')
            if CWD_FILTER and CWD_FILTER not in cwd: continue
            with open(f) as fh:
                blob = fh.read()
            if NEEDLE.search(blob):
                hits.append((f, cwd))
        except Exception: pass

hits.sort(key=lambda x: os.path.getmtime(x[0]), reverse=True)
for f, cwd in hits[:15]:
    print(f'{f}')
    print(f'  cwd: {cwd}')
    print(f'  first prompt: {first_user_prompt(f)[:300]}\n')
PY
```

For initial triage, a plain `grep -l` is faster:

```bash
grep -l -i 'reencrypt\|re-encrypt' -r ~/.pi/agent/sessions --include='*.jsonl' | head -20
```

Then run operation 3 on each candidate to identify the right one.

## Output Guidelines

- Always show the **full session file path** so the user (or you) can do follow-ups.
- Truncate long content in listings — show full content only when reading a specific session.
- Format timestamps as human-readable (`YYYY-MM-DD HH:MM`).
- When presenting a conversation, clearly distinguish user / assistant / toolResult turns.
- If a session has many messages, summarize or paginate — ask the user how much detail they want.
- Never include `thinking` content blocks in human-facing output — they are large, encrypted, and meaningless.

## Rules

- **Read-only.** Never modify, delete, or move session files. Pi has its own `/resume` flow for managing them.
- **Use the header `cwd`, not the encoded directory name.** The directory name is a one-way encoding; the header is the source of truth.
- **Skip `thinking` content blocks.** They contain encrypted reasoning blobs that are long and unreadable.
- **Filter out subagent run files by default.** Files matching `*/run-*/session.jsonl` are pi-subagents fan-out runs, not top-level sessions. Include them only when the user explicitly asks.
- **Handle both string and array `content`.** UserMessage.content can be either form — always check.
- **Truthful output.** Never fabricate session content or paths. If a search returns nothing, say so.
- **Show paths.** Every result must include the absolute path to the session file.

---
name: session-history
description: Browse and search OpenCode conversation history from the local SQLite database. List sessions, read past conversations, and search across sessions by keyword.
---

## Purpose

Query the OpenCode SQLite database to retrieve past session context. Use this to recall what was discussed, what tools were used, and what changes were made in previous conversations.

## Database Reference

- **Location**: `~/.local/share/opencode/opencode.db`
- **Query method**: `python3 -c "import sqlite3, json; ..."`
- **Timestamps**: All stored as **epoch milliseconds** (divide by 1000 for `datetime.fromtimestamp`)

### Schema

**`project`** — Maps project IDs to worktree paths.

| Column     | Type | Notes                         |
| ---------- | ---- | ----------------------------- |
| `id`       | TEXT | Primary key                   |
| `worktree` | TEXT | Absolute path to project root |

**`session`** — One row per conversation session.

| Column         | Type    | Notes                             |
| -------------- | ------- | --------------------------------- |
| `id`           | TEXT    | Primary key (e.g. `ses_...`)      |
| `project_id`   | TEXT    | FK to project                     |
| `title`        | TEXT    | Auto-generated session title      |
| `directory`    | TEXT    | Working directory for the session |
| `time_created` | INTEGER | Epoch ms                          |
| `time_updated` | INTEGER | Epoch ms                          |

**`message`** — One row per user or assistant turn.

| Column         | Type    | Notes                                                             |
| -------------- | ------- | ----------------------------------------------------------------- |
| `id`           | TEXT    | Primary key (e.g. `msg_...`)                                      |
| `session_id`   | TEXT    | FK to session                                                     |
| `time_created` | INTEGER | Epoch ms                                                          |
| `data`         | TEXT    | JSON: `role` (user/assistant), `agent`, `model`, `cost`, `tokens` |

**`part`** — Individual content parts within a message.

| Column         | Type    | Notes                                         |
| -------------- | ------- | --------------------------------------------- |
| `id`           | TEXT    | Primary key                                   |
| `message_id`   | TEXT    | FK to message                                 |
| `session_id`   | TEXT    | FK to session (denormalized for fast queries) |
| `time_created` | INTEGER | Epoch ms                                      |
| `data`         | TEXT    | JSON — structure depends on `type` field      |

### Part Types

The `data` JSON always has a `type` field. Known types:

- **`text`** — Conversation text. Key: `data.text`
- **`tool`** — Tool invocation + result. Keys: `data.tool` (tool name string), `data.state.input` (args), `data.state.output` (result), `data.state.status`
- **`patch`** — File edit diff
- **`file`** — File reference
- **`step-start`** / **`step-finish`** — Step boundaries (ignore for content)
- **`compaction`** — Context compaction marker (ignore for content)

## Operations

### 1. List Recent Sessions

```python
python3 -c "
import sqlite3, json
from datetime import datetime
conn = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
c = conn.cursor()
c.execute('''SELECT id, title, directory, time_created, time_updated
             FROM session ORDER BY time_updated DESC LIMIT 20''')
for r in c.fetchall():
    created = datetime.fromtimestamp(r[3]/1000).strftime('%Y-%m-%d %H:%M')
    updated = datetime.fromtimestamp(r[4]/1000).strftime('%Y-%m-%d %H:%M')
    print(f'{r[0]}  {updated}  {r[2]}')
    print(f'  {r[1]}')
    print()
"
```

To filter by project directory, add `WHERE directory LIKE '%some/path%'` or join with `project`:

```python
c.execute('''SELECT s.id, s.title, s.directory, s.time_updated
             FROM session s JOIN project p ON s.project_id = p.id
             WHERE p.worktree LIKE '%project-name%'
             ORDER BY s.time_updated DESC LIMIT 20''')
```

### 2. Read a Session's Conversation

Retrieve all text and tool parts for a session, ordered chronologically. Join with `message` to get the role:

```python
python3 -c "
import sqlite3, json
from datetime import datetime
SESSION_ID = 'ses_XXXXX'  # Replace with actual session ID
conn = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
c = conn.cursor()
c.execute('''SELECT m.data as mdata, p.data as pdata, p.time_created
             FROM part p JOIN message m ON p.message_id = m.id
             WHERE p.session_id = ?
             ORDER BY p.time_created''', (SESSION_ID,))
for mdata_str, pdata_str, ts in c.fetchall():
    mdata = json.loads(mdata_str)
    pdata = json.loads(pdata_str)
    role = mdata.get('role', '?')
    ptype = pdata.get('type', '?')
    time = datetime.fromtimestamp(ts/1000).strftime('%H:%M:%S')
    if ptype == 'text':
        text = pdata.get('text', '')[:300].replace(chr(10), ' ')
        if text.strip():
            print(f'[{time}] {role}: {text}')
    elif ptype == 'tool':
        tool_name = pdata.get('tool', '?')
        state = pdata.get('state', {})
        inp = json.dumps(state.get('input', {}))[:150]
        out = str(state.get('output', ''))[:150].replace(chr(10), ' ')
        print(f'[{time}] TOOL {tool_name}: {inp}')
        print(f'         -> {out}')
"
```

For full untruncated content, increase the slice lengths or remove them.

### 3. Search Across Sessions

Search for keywords in conversation text across all sessions:

```python
python3 -c "
import sqlite3, json
from datetime import datetime
QUERY = '%search term%'  # Replace with search term (SQL LIKE pattern)
conn = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
c = conn.cursor()
c.execute('''SELECT DISTINCT s.id, s.title, s.directory, s.time_updated
             FROM part p
             JOIN session s ON p.session_id = s.id
             WHERE p.data LIKE ?
             ORDER BY s.time_updated DESC LIMIT 10''', (QUERY,))
for r in c.fetchall():
    updated = datetime.fromtimestamp(r[3]/1000).strftime('%Y-%m-%d %H:%M')
    print(f'{r[0]}  {updated}  {r[2]}')
    print(f'  {r[1]}')
    print()
"
```

To also see the matching text snippets, query the parts directly:

```python
c.execute('''SELECT p.session_id, p.data, p.time_created
             FROM part p
             WHERE p.data LIKE ?
             ORDER BY p.time_created DESC LIMIT 20''', (QUERY,))
```

## Output Guidelines

- Always show session IDs so the user (or you) can do follow-up queries
- Truncate long text content in listings — show full content only when reading a specific session
- Format timestamps as human-readable dates
- When presenting a session conversation, clearly distinguish user messages from assistant messages and tool calls
- If a session has many messages, summarize or paginate — ask the user how much detail they want

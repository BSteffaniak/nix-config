---
name: self-improve-skill
description: Analyze how a skill execution went and propose fixes to the SKILL.md source. Interactive — reviews the conversation for command failures, workarounds, and deviations, then applies approved changes.
allowed-tools: Bash(git:*), Bash(python3:*), Read(*), Write(*), Question(*)
---

## Purpose

Review how a skill execution actually went — in the current conversation or a past session — and propose targeted fixes to the skill's SKILL.md source file. The skill looks for command failures, platform incompatibilities, missing steps, unnecessary steps, incorrect assumptions, and other discrepancies between what the SKILL.md prescribed and what actually happened. Each proposed change is reviewed individually before being written to the nix repo source.

## Critical Path Rule

Skills are managed as nix config and deployed via symlinks:

- **Source of truth**: `~/.config/nix/configs/opencode/skills/<name>/SKILL.md`
- **Symlinked to**: `~/.config/opencode/skills/<name>/SKILL.md` (managed by nix, read-only)

**NEVER read from or write to `~/.config/opencode/skills/`.** That directory is a nix-managed symlink target. Any changes written there will be silently overwritten on the next nix rebuild. Always operate on the source at `~/.config/nix/configs/opencode/skills/`.

## Steps

### 1. Identify the target skill

Determine which skill to review. There are three modes, tried in order:

#### Explicit argument

If the user provides a skill name (e.g., "self-improve-skill video-analyze" or "improve the video-analyze skill"), use it directly.

#### Auto-detect from current conversation

Scan the current conversation context for skill loading indicators. Look for:

- `<skill_content name="...">` tags — these are injected when a skill is loaded via the `skill` tool
- Skill tool invocations — the Skill tool call with a `name` parameter
- References to a skill SKILL.md being read

If exactly one skill was loaded in this conversation, use it. If multiple were loaded, ask the user which one to review.

#### Past session via database

If the user references a past session (e.g., "improve the skill from my last session", "review session ses_abc123"), query the OpenCode SQLite database to find the skill execution:

```bash
python3 -c "
import sqlite3, json
SESSION_ID = 'ses_XXXXX'  # Replace with actual session ID, or use most recent
conn = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
c = conn.cursor()

# If no session ID given, find the most recent session (excluding current)
if SESSION_ID == 'latest':
    c.execute('''SELECT id, title FROM session
                 ORDER BY time_updated DESC LIMIT 5''')
    for row in c.fetchall():
        print(f'{row[0]}  {row[1]}')
else:
    # Find skill tool invocations in the session
    c.execute('''SELECT p.data FROM part p
                 WHERE p.session_id = ?
                 ORDER BY p.time_created''', (SESSION_ID,))
    for (pdata_str,) in c.fetchall():
        pdata = json.loads(pdata_str)
        if pdata.get('type') == 'tool' and pdata.get('tool') == 'Skill':
            inp = pdata.get('state', {}).get('input', {})
            print(f'Skill loaded: {inp.get(\"name\", \"unknown\")}')
"
```

#### Verify the skill exists

Once the skill name is determined, verify the source file exists:

```bash
ls ~/.config/nix/configs/opencode/skills/<name>/SKILL.md
```

If it doesn't exist, warn the user and ask for correction.

### 2. Gather execution context

Collect evidence of how the skill execution actually went. The goal is to build a list of **events** — each event is a command or action that was attempted, its result, and whether it deviated from the skill's instructions.

#### From the current conversation

Scan the conversation for:

- **Tool calls and their outputs**: Every Bash command, Read, Write, Question, and other tool invocations
- **Error patterns**: Look for commands that returned non-zero exit codes, error messages, stack traces, "command not found", permission denied, etc.
- **Retry sequences**: A command that failed followed by a modified version of the same command — this is the most valuable signal, as it means the skill's prescribed command didn't work
- **Workarounds**: The agent doing something not described in the SKILL.md to achieve a step's goal
- **Skipped steps**: Steps from the SKILL.md that were never executed
- **Reordered steps**: Steps executed in a different order than prescribed
- **Added steps**: Things the agent did that aren't in the SKILL.md at all

#### From a past session (database)

Query the session's tool parts to reconstruct the execution:

```bash
python3 -c "
import sqlite3, json
SESSION_ID = 'ses_XXXXX'
conn = sqlite3.connect('$HOME/.local/share/opencode/opencode.db')
c = conn.cursor()
c.execute('''SELECT p.data, p.time_created FROM part p
             JOIN message m ON p.message_id = m.id
             WHERE p.session_id = ?
             ORDER BY p.time_created''', (SESSION_ID,))
events = []
for pdata_str, ts in c.fetchall():
    pdata = json.loads(pdata_str)
    ptype = pdata.get('type')
    if ptype == 'tool':
        tool = pdata.get('tool', '?')
        state = pdata.get('state', {})
        status = state.get('status', '?')
        inp = state.get('input', {})
        out = str(state.get('output', ''))
        # Flag errors
        is_error = status == 'error' or 'error' in out.lower()[:500] or 'not found' in out.lower()[:500]
        events.append({
            'tool': tool, 'input': inp, 'output': out[:1000],
            'status': status, 'is_error': is_error, 'ts': ts
        })
        if is_error:
            print(f'ERROR [{tool}]: {json.dumps(inp)[:200]}')
            print(f'  -> {out[:200]}')
            print()
    elif ptype == 'text':
        text = pdata.get('text', '')
        if text.strip():
            events.append({'type': 'text', 'text': text[:500], 'ts': ts})
print(f'Total events: {len(events)}')
print(f'Errors: {sum(1 for e in events if e.get(\"is_error\"))}')
"
```

#### Build the event log

Organize the gathered events into a structured timeline:

```
1. [OK]    Bash: find ~/Desktop ~/Movies ... → found 3 videos
2. [OK]    Question: asked user to pick video → user selected recording.mov
3. [ERROR] Bash: ffprobe -v quiet ... → "ffprobe: command not found"
4. [OK]    Bash: nix shell nixpkgs#ffmpeg -c ffprobe ... → got metadata
5. [OK]    Bash: ffmpeg ... -vf "fps=5,scale=..." → extracted 45 frames
6. [SKIP]  Step 5 presentation batching — agent showed all frames at once
```

### 3. Read the current SKILL.md

Read the skill's source file from the **nix repo** (never the symlink):

```bash
# Correct — nix repo source
cat ~/.config/nix/configs/opencode/skills/<name>/SKILL.md
```

Use the Read tool to read the full SKILL.md. Also check for and read any `_shared/` references:

```bash
# Check if the SKILL.md references any _shared/ files
grep -o '_shared/[a-z0-9-]*\.md' ~/.config/nix/configs/opencode/skills/<name>/SKILL.md
```

If shared files are referenced, read those too — issues may be in the shared content rather than the skill itself.

### 4. Analyze discrepancies

Compare the SKILL.md's prescribed behavior against the actual execution events from Step 2. For each discrepancy, create a **finding** with:

- **Category** — what type of issue it is
- **Severity** — how impactful it is
- **Evidence** — what actually happened (from the event log)
- **Location** — which section of the SKILL.md is affected
- **Proposed fix** — the specific text change needed

#### Finding categories

Ordered by severity (analyze in this order):

**Critical** — The skill's instructions are broken:

- **Command failure**: A prescribed command errored and had to be replaced. E.g., `find -printf` doesn't work on macOS but the skill only showed the Linux variant.
- **Missing prerequisite**: A tool, auth, or config was needed but not listed in Prerequisites. E.g., `ffprobe` wasn't installed and the skill didn't mention the nix fallback.
- **Wrong output format**: A command's output didn't match what the skill expected, causing downstream parsing to fail.

**Important** — The skill's instructions are incomplete or misleading:

- **Missing step**: The agent had to do something not described in any step. E.g., creating a directory that the skill assumed existed.
- **Missing error handling**: A step failed and the skill had no guidance for recovery. E.g., "if the video has no audio stream, ffprobe returns different JSON structure."
- **Platform incompatibility**: Commands that work on one OS but not another. E.g., `stat -f` (macOS) vs `stat -c` (Linux).
- **Incorrect default**: A hardcoded value, path, or assumption that was wrong. E.g., wrong default directory for screen recordings.
- **Missing rule**: A constraint that should exist but wasn't documented. E.g., the agent hit an API limit that should have been mentioned in Rules.

**Minor** — The skill works but could be better:

- **Unnecessary step**: A step that was always skipped because it's not needed.
- **Inefficient command**: A command that could be simplified or combined with another.
- **Unclear instruction**: A step whose wording caused the agent to misinterpret what to do.
- **Missing example**: A step that would benefit from a concrete example command or expected output.
- **Outdated information**: References to tools, APIs, or behaviors that have changed.

#### Analysis process

For each event in the timeline:

1. Find the corresponding step in the SKILL.md
2. Check if the event matches what the SKILL.md prescribed
3. If not, determine why — categorize and assess severity
4. Draft the specific text change (old text → new text) targeting the exact lines in the SKILL.md

If no discrepancies are found, report that the skill executed cleanly and no changes are needed. Do not invent problems.

### 5. Propose changes (per-item review loop)

Present each finding one at a time, ordered by severity (critical first, then important, then minor).

For each finding, display:

```
## Finding 1/N: <category> (<severity>)

**What happened**: <description of the discrepancy with evidence from the event log>

**Affected section**: Step N — <step name> (lines X–Y)

**Before**:
```

<the current text in the SKILL.md>
```

**After**:

```
<the proposed replacement text>
```

````

Then use the Question tool:

```json
{
  "questions": [
    {
      "header": "Finding 1/N",
      "question": "Apply this change to the SKILL.md?",
      "options": [
        { "label": "Approve", "description": "Apply this change" },
        { "label": "Regenerate", "description": "Redraft the proposed fix" },
        { "label": "Skip", "description": "Don't make this change" }
      ]
    }
  ]
}
````

Handle responses:

- **Approve** — Queue the change for writing. Move to the next finding.
- **Regenerate** — Redraft the proposed fix with a different approach. Re-present. Do not advance.
- **Skip** — Drop this finding. Move to the next finding.
- **Custom text** — Apply the user's edits to the proposed fix. Re-present for confirmation. Do not advance.

After all findings are reviewed, show a summary:

```
## Summary

Approved: 3 changes (2 critical, 1 important)
Skipped: 1 change (1 minor)

Ready to apply approved changes to:
  ~/.config/nix/configs/opencode/skills/<name>/SKILL.md
```

### 6. Apply approved changes

Apply all approved changes to the SKILL.md source file:

1. Read the current SKILL.md one more time to ensure it hasn't changed since Step 3
2. Apply each approved change in order (from bottom of file to top, to preserve line numbers)
3. Write the updated file to `~/.config/nix/configs/opencode/skills/<name>/SKILL.md`

**Never write to `~/.config/opencode/skills/`** — that is a nix-managed symlink.

After writing, show the git diff:

```bash
git -C ~/.config/nix diff configs/opencode/skills/<name>/SKILL.md
```

If `_shared/` files were also modified, show those diffs too.

Report completion:

```
Applied 3 changes to configs/opencode/skills/<name>/SKILL.md

Changes take effect after nix rebuild:
  darwin-rebuild switch --flake ~/.config/nix    # macOS
  nixos-rebuild switch --flake ~/.config/nix     # NixOS
  home-manager switch --flake ~/.config/nix      # standalone

Or for immediate testing, the source file can be read directly.
```

## Rules

- **Never modify `~/.config/opencode/skills/`.** That directory is managed by nix via symlinks. Always read from and write to `~/.config/nix/configs/opencode/skills/`. Modifying the symlink target is silently overwritten on rebuild and achieves nothing.
- **Only fix what was observably wrong.** Every proposed change must be backed by evidence from the execution — a command that failed, a step that was skipped, an error that occurred. Do not refactor for style, restructure the skill, or make speculative improvements.
- **Show diffs for every proposed change.** Never write to the SKILL.md without the user having reviewed the before/after for each change. The per-item review loop in Step 5 is mandatory.
- **Process findings one at a time.** Present each finding individually with its own Question gate. Never batch multiple findings into a single approval.
- **Critical findings first.** Always present command failures and broken instructions before missing steps, and missing steps before efficiency improvements.
- **Preserve the skill's structural pattern.** Do not change the fundamental approach, step ordering, or pattern of a skill. Fixes should be surgical — change the minimum text needed to resolve the issue.
- **If nothing is wrong, say so.** If the skill executed cleanly with no discrepancies, report that no changes are needed. Do not invent problems to justify the skill's existence.
- **Respect the user's edits.** If the user provides custom text for a proposed change, use their wording faithfully. Do not re-edit their words.
- **Handle `_shared/` files correctly.** If a discrepancy is in a `_shared/` file referenced by the skill, propose the fix to the shared file — but warn that it may affect other skills that reference the same file. List all skills that use the shared file.
- **Never skip a gate.** Every proposed change must go through the Question tool for user approval. Never apply changes without explicit confirmation.

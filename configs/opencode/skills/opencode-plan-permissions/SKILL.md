---
name: opencode-plan-permissions
description: Plan precise read-only plan-agent permission updates from current conversation context or ad-hoc instructions. Interactive — analyzes existing permissions, reviews rules one-by-one, and outputs a build-agent handoff.
allowed-tools: Bash(git:*), Bash(python3:*), Question(*)
---

## Purpose

`opencode-plan-permissions` helps you design safe, precise read-only command allowlists for the plan agent by using either the current conversation context or a direct ad-hoc request, comparing proposals against existing `configs/opencode/permissions/*.json` patterns, and producing an exact handoff plan for later execution in the build agent.

## Steps

### 1. Resolve input mode and scope

Determine the permission-planning input source before analyzing commands:

- If the user supplied a direct request as invocation arguments (for example: "add read-only ffmpeg commands to the plan agent"), treat that as the primary scope.
- If no explicit scope was provided, extract goals and command families from the current conversation context.
- If both are present, use the **Question tool** to choose the source of truth:

```json
{
  "questions": [
    {
      "header": "Input source",
      "question": "Which instructions should I use for this permission plan?",
      "options": [
        {
          "label": "Invocation text",
          "description": "Use the ad-hoc request passed with this skill run"
        },
        {
          "label": "Conversation context",
          "description": "Use goals inferred from earlier messages in this chat"
        },
        {
          "label": "Merge both",
          "description": "Combine both sources and resolve conflicts explicitly"
        }
      ]
    }
  ]
}
```

Normalize the selected scope into:

- target command families (for example `ffmpeg`, `file`, `otool`)
- read-only intent constraints
- exclusions or risk boundaries the user already stated

### 2. Locate the nix config repo and inspect permission baseline

Do not assume the current working directory is the nix config repo. Resolve the repo first, then scan existing permission files.

#### Resolve repo path

Use this priority order:

1. If invocation text includes an explicit repo path, use it.
2. Else, if current directory is inside a git repo that contains `configs/opencode/permissions/`, use that repo.
3. Else, probe common locations (`~/.config/nix`, `~/.config/nixos`) and keep only those that contain `configs/opencode/permissions/`.
4. If multiple valid candidates remain, ask the user to choose.
5. If none are found, ask the user for the path.

```bash
python3 - <<'PY'
from pathlib import Path
import subprocess, os

def git_root():
    try:
        out = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
        return Path(out)
    except Exception:
        return None

def is_opencode_repo(path: Path) -> bool:
    return (path / "configs" / "opencode" / "permissions").is_dir()

candidates = []

cwd_root = git_root()
if cwd_root and is_opencode_repo(cwd_root):
    candidates.append(cwd_root)

for p in [Path.home()/".config"/"nix", Path.home()/".config"/"nixos"]:
    if is_opencode_repo(p):
        candidates.append(p)

# Deduplicate while preserving order
seen = set()
uniq = []
for c in candidates:
    s = str(c.resolve())
    if s not in seen:
        uniq.append(c)
        seen.add(s)

print("CANDIDATES")
for c in uniq:
    print(c)
PY
```

If exactly one candidate is found, set it as `REPO_ROOT`. Otherwise, use the **Question tool**:

```json
{
  "questions": [
    {
      "header": "Select repo",
      "question": "Which nix config repo should I use for permission planning?",
      "options": [
        {
          "label": "~/.config/nix",
          "description": "Contains configs/opencode/permissions"
        },
        {
          "label": "~/.config/nixos",
          "description": "Contains configs/opencode/permissions"
        }
      ]
    }
  ]
}
```

#### Inspect baseline rules

After `REPO_ROOT` is selected, enumerate plan-agent bash rules from:

- `configs/opencode/opencode.json`
- `configs/opencode/permissions/*.json`

and build a baseline map of defaults, current allows, and current denies.

### 3. Generate candidate read-only permission rules

Translate the selected scope into candidate command patterns that are precise enough to be safe and broad enough to be useful.

For each command family:

1. Start from a default deny posture (for example, keep `"<cmd> *": "deny"` unless a narrower baseline already exists).
2. Enumerate read-only subcommands and flags that inspect metadata, versions, help text, or stream-to-stdout behavior.
3. Exclude mutating actions (writes, deletes, moves, installs, network pushes, system changes).
4. Propose explicit allow patterns for safe forms and explicit deny patterns for known risky forms.
5. Include both bare command and wildcard variants only where needed for usability (for example `file` and `file *`).

#### Precision heuristics

- Prefer `"<cmd> <safe-subcommand> *"` over `"<cmd> *"`.
- Allow broad wildcard only when the command is inherently read-only in all common usages.
- Add guard denies for ambiguous commands where read/write depends on flags.
- Preserve existing repo conventions for key shape and ordering.

#### Example candidate outputs

For `file`:

```json
{
  "file": "allow",
  "file *": "allow"
}
```

For read-only `ffmpeg` inspection workflows (no file outputs):

```json
{
  "ffmpeg *": "deny",
  "ffmpeg -version": "allow",
  "ffmpeg -version *": "allow",
  "ffmpeg -formats": "allow",
  "ffmpeg -formats *": "allow",
  "ffmpeg -codecs": "allow",
  "ffmpeg -codecs *": "allow",
  "ffmpeg -decoders": "allow",
  "ffmpeg -decoders *": "allow",
  "ffmpeg -encoders": "allow",
  "ffmpeg -encoders *": "allow",
  "ffmpeg -filters": "allow",
  "ffmpeg -filters *": "allow",
  "ffmpeg -i * -f null -": "allow"
}
```

Include a one-line safety rationale for every proposed pattern.

### 4. Review proposed patterns one-by-one

Present each candidate permission pattern individually, with context and rationale, and require an explicit decision before proceeding.

For each item, show:

- target file (for example `configs/opencode/permissions/binary-tools.json`)
- exact JSON key/value proposal
- why it is considered read-only
- what risk is reduced by its precision

Then use the **Question tool**:

```json
{
  "questions": [
    {
      "header": "Rule review",
      "question": "What should I do with this permission pattern?",
      "options": [
        { "label": "Approve", "description": "Keep as-is and continue" },
        {
          "label": "Regenerate",
          "description": "Redraft a safer or more useful variant"
        },
        { "label": "Skip", "description": "Drop this pattern" }
      ]
    }
  ]
}
```

Handle responses:

- **Approve** — include in final plan and move to next item
- **Regenerate** — produce a revised variant and re-present the same item
- **Skip** — exclude and move to next item
- **Custom text** — apply the user's exact edited rule, re-present for confirmation

### 5. Produce build-agent handoff (no writes)

After review is complete, output a precise implementation handoff the user can run in build mode.

The handoff must include:

1. **Selected repo root** (absolute path)
2. **Files to update** under `configs/opencode/permissions/`
3. **Approved rule set** (only approved items)
4. **Merge intent** (add/replace/remove per key)
5. **Validation plan**:
   - confirm `agent.plan.permission.bash` still defaults to deny
   - confirm only intended command patterns are newly allowed
   - confirm no mutating command families were accidentally broadened

Also output a ready-to-paste build-agent prompt, for example:

```text
Apply the following approved read-only plan-agent permission updates in <REPO_ROOT>:

1) Edit <file A>:
- add key "<pattern>": "allow"
- add key "<pattern>": "deny"

2) Edit <file B>:
- ...

Then show the final diff and verify:
- plan agent remains deny-by-default
- only approved read-only patterns were changed
- no writes were introduced
```

Do not write files, create commits, or run mutating commands in this skill.

### 6. Final confirmation summary

Present a final summary before ending:

- approved patterns
- skipped patterns
- unresolved items requiring user input
- final build-agent handoff prompt

Use the **Question tool** for final confirmation:

```json
{
  "questions": [
    {
      "header": "Final review",
      "question": "Does this permission plan look correct?",
      "options": [
        {
          "label": "Done",
          "description": "Finalize the read-only plan output"
        },
        {
          "label": "Regenerate summary",
          "description": "Rebuild the final plan presentation"
        }
      ]
    }
  ]
}
```

If the user provides custom text, apply those edits to the final output exactly.

## Rules

- **Read-only planning only.** Never edit files, write JSON, or execute mutating commands in this skill; output plans and handoff text only.
- **Never assume repo location.** Always resolve the nix config repo dynamically; support invocation from unrelated directories and handle both `~/.config/nix` and `~/.config/nixos` when present.
- **Ad-hoc input is first-class.** The skill must work with direct prompts (for example, "add read-only ffmpeg commands") without requiring prior conversation context.
- **Conversation context is optional.** Use prior conversation goals only when available and user-selected; never invent missing context.
- **Precision over breadth.** Prefer explicit safe subcommand patterns over broad wildcards; only allow wildcard patterns when the command family is reliably read-only.
- **Preserve deny-by-default.** Plan-agent permission sets must remain deny-first, with narrow allow exceptions.
- **Never skip a gate.** Every decision gate (source selection, per-item review, final review) must be completed before finalizing output.
- **Never act without user confirmation.** Only approved patterns appear in the final handoff.
- **One item at a time.** Review command patterns individually; do not batch approvals.
- **Respect user edits exactly.** If the user provides custom pattern text, preserve it faithfully in the final plan.
- **Truthful output.** Do not fabricate existing rules, file contents, or command safety claims.

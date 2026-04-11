---
name: nvim-diagnose
description: Diagnose neovim startup errors and runtime issues. Interactive — captures diagnostics, categorizes errors, and traces root causes to config files.
allowed-tools: Bash(nvim:*), Bash(git:*), Question(*)
---

## Purpose

Troubleshoot neovim startup errors, plugin failures, and runtime issues by capturing
diagnostics and tracing them to their root cause in the configuration. Supports two modes:
automatic capture via `nvim --headless` and manual input where the user pastes error text
directly. Outputs a categorized report with source file references and actionable fix
suggestions — never edits files.

## Prerequisites

- `nvim` must be on PATH
- The nix config repo (containing `configs/neovim/`) must be accessible from the
  current working directory or a parent

## Steps

### 1. Determine input mode

Ask the user how to gather error information:

```json
{
  "questions": [
    {
      "header": "Input mode",
      "question": "How should I gather the error information?",
      "options": [
        {
          "label": "Auto-capture",
          "description": "Run nvim --headless to capture startup messages and checkhealth output"
        },
        {
          "label": "Paste errors",
          "description": "I'll paste the error text for you to analyze"
        }
      ]
    }
  ]
}
```

- **Auto-capture** → proceed to Step 2
- **Paste errors** → ask the user to paste their error text, then skip to Step 3
- **Custom text** → the user may describe a specific symptom; treat as manual input

### 2. Capture diagnostics

Run headless neovim commands to gather diagnostic data. Always capture both stdout and
stderr (`2>&1`). Use a 30-second timeout per command to avoid hangs from plugins that
block in headless mode.

#### 2a. Startup errors

```bash
nvim --headless -c 'qa!' 2>&1
```

Errors printed to stderr during startup appear here. This is the most reliable capture —
any plugin that throws during `init.lua` processing will surface.

#### 2b. Startup messages

```bash
nvim --headless -c 'lua vim.defer_fn(function() local m = vim.api.nvim_exec2("messages", {output=true}).output; local f = io.open("/tmp/nvim-diag-msgs.txt", "w"); if f then f:write(m); f:close() end; vim.cmd("qa!") end, 3000)' 2>&1
```

The 3-second defer allows lazy-loaded plugins to initialize and emit messages. Read
`/tmp/nvim-diag-msgs.txt` for the captured `:messages` output.

If this command hangs or produces no output, fall back to:

```bash
nvim --headless -c 'redir! > /tmp/nvim-diag-msgs.txt | silent messages | redir END | qa!' 2>&1
```

#### 2c. Checkhealth

```bash
nvim --headless -c 'checkhealth' -c 'lua vim.defer_fn(function() vim.cmd("w! /tmp/nvim-diag-health.txt"); vim.cmd("qa!") end, 5000)' 2>&1
```

Read `/tmp/nvim-diag-health.txt`. Focus on lines containing `ERROR` or `WARN`.

#### 2d. Lazy.nvim plugin status

```bash
nvim --headless -c 'lua vim.defer_fn(function() local ok, lazy = pcall(require, "lazy"); if ok then for _, p in ipairs(lazy.plugins()) do local s = p._.loaded and "loaded" or (p._.cond == false and "disabled" or "not-loaded"); io.stderr:write(s .. ": " .. p.name .. "\n") end end; vim.cmd("qa!") end, 3000)' 2>&1
```

Note: Plugins configured with `lazy = true` will show as `not-loaded` in headless mode.
This is normal — only flag plugins that are `not-loaded` when they should be eager, or
that have error messages associated with them.

#### 2e. Runtime dependency checks

```bash
nvim --headless -c 'lua for _, cmd in ipairs({"fzf", "rg", "fd", "node", "git", "luarocks", "stylua", "lua-language-server"}) do io.stderr:write(cmd .. ": " .. (vim.fn.executable(cmd) == 1 and "found" or "MISSING") .. "\n") end; vim.cmd("qa!")' 2>&1
```

**If any command hangs or fails**, note it in findings and continue with the remaining
diagnostics. Adapt command syntax as needed — the exact invocations above are starting
points and may need adjustment depending on the neovim version and plugin state.

### 3. Parse and categorize

Review all captured output and group findings into these categories:

| Category                 | Indicators                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------- |
| **Plugin load failures** | `Error detected while processing`, lazy.nvim error notifications, `E5113`, module not found |
| **LSP errors**           | `client_id`, `lsp`, server name mentions, `mason`, `lspconfig`                              |
| **Treesitter errors**    | `treesitter`, `parser`, `ts_`, `query`, `highlight`                                         |
| **Deprecation warnings** | `deprecated`, `vim.lsp.buf_*`, removed API mentions                                         |
| **Missing runtime deps** | `MISSING` from dep check, `executable not found`, `command not found`                       |
| **Checkhealth issues**   | Lines from checkhealth containing `ERROR` or `WARN`                                         |
| **Other**                | Anything that doesn't fit the above                                                         |

For each finding, record:

- **Category**: from the table above
- **Severity**: ERROR or WARNING
- **Raw text**: the exact error/warning message
- **Source hint**: any file paths, plugin names, or function names mentioned in the error

### 4. Present findings summary

Show a categorized summary of everything found:

```
## Diagnostic Summary

### Plugin load failures (3 errors)
- [ERROR] Failed to load 'nvim-treesitter': ...
- [ERROR] ...
- [WARN] ...

### LSP errors (1 error)
- [ERROR] ...

### Checkhealth issues (5 warnings)
- [WARN] ...
...

### Missing runtime deps (0)
All checked.
```

Then ask which categories to investigate further:

```json
{
  "questions": [
    {
      "header": "Investigate",
      "question": "Which categories should I trace to their root cause in the config?",
      "multiple": true,
      "options": [
        {
          "label": "<Category> (N errors)",
          "description": "Brief summary of the errors"
        }
      ]
    }
  ]
}
```

Build the options dynamically from actual findings. Only show categories that have at
least one finding. If there are no findings at all, report a clean bill of health and stop.

### 5. Deep analysis

For each selected category, investigate the root cause by reading the relevant
config source files.

#### 5a. Locate the config

The neovim config lives in the nix config repo. Find the repo root:

```bash
git rev-parse --show-toplevel
```

Key config files to examine based on error category:

| Error relates to...            | Check these files                                                          |
| ------------------------------ | -------------------------------------------------------------------------- |
| Plugin loading, lazy.nvim      | `configs/neovim/lua/bsteffaniak/lazy.lua`, `configs/neovim/lazy-lock.json` |
| Core settings, fzf-lua         | `configs/neovim/lua/bsteffaniak/set.lua`                                   |
| LSP, format-on-save            | `configs/neovim/lua/bsteffaniak/lsp.lua`                                   |
| LSP server installation, Mason | `configs/neovim/lua/config/lsp/installer.lua`                              |
| null-ls / none-ls              | `configs/neovim/lua/config/lsp/none-ls/init.lua`                           |
| Keybindings                    | `configs/neovim/lua/bsteffaniak/keymap.lua`                                |
| Per-host plugin toggles        | `home/modules/editors/neovim.nix` (generates `host-config.lua`)            |
| Filetype-specific              | `configs/neovim/ftplugin/<ft>.lua`                                         |
| Nix package availability       | `home/modules/editors/neovim.nix` (home.packages)                          |

#### 5b. Trace root cause

For each error, read the relevant source files and determine why it occurs. Common
root causes:

- **Plugin API change** — A pinned version in `lazy-lock.json` has a breaking change
  vs what the config expects. Check the plugin's changelog or commit history.
- **Missing Nix package** — A tool the config expects (LSP server, formatter, linter)
  isn't in `home.packages` in `neovim.nix`.
- **host-config mismatch** — `host-config.lua` enables a plugin that has missing
  dependencies, or disables one that other plugins depend on.
- **Neovim API deprecation** — Config uses a removed or renamed vim API. Check the
  neovim version (`nvim --version`) against the API docs.
- **Lazy-load race condition** — A plugin tries to use another plugin that hasn't
  loaded yet. Common with fzf-lua on first open (its dependencies haven't been
  triggered).
- **Mason conflict** — Mason tries to install servers on a Nix-managed system despite
  the `is_nix_system()` guard. Check if the guard is working correctly.
- **Stale lockfile** — `lazy-lock.json` pins an old version that's incompatible with
  the current neovim version.

#### 5c. Format each finding

For each traced error, produce:

```
**Finding N: <brief title>**
- **Category**: <category>
- **Severity**: ERROR / WARNING
- **Raw error**: `<exact error text>`
- **Root cause**: <explanation of why this happens>
- **Config location**: `<file>:<line>` — <what this code does>
- **Suggested fix**: <specific change to make, with before/after if helpful>
```

Always include the file path relative to the repo root and the exact line number.

### 6. Final report

Present a complete structured report:

```
## Neovim Diagnostic Report

### Environment
- neovim version: <output of nvim --version, first line>
- OS: <darwin/linux>
- Nix-managed: <yes/no, based on is_nix_system check>
- Host config: <which host-config.lua plugins are enabled>

### Findings

#### 1. [ERROR] <brief description>
- **Category**: Plugin load failure
- **Raw error**: `<exact error text>`
- **Root cause**: <explanation>
- **Config location**: `configs/neovim/lua/bsteffaniak/lazy.lua:42`
- **Suggested fix**: <concrete fix with before/after>

#### 2. [WARN] <brief description>
...

### Clean categories
<list categories that had no issues>

### Notes
<any caveats: commands that timed out, headless-mode limitations,
things that could only be checked at runtime, etc.>
```

Sort findings by severity (errors first, then warnings). Within the same severity,
group by category.

## Rules

- **Diagnose only.** Never edit, write, or delete any files. Only read files and
  report findings.
- **Trace to source.** Every finding must reference the specific config file and line
  number where the issue originates. Vague advice like "check your config" is not
  acceptable.
- **Concrete fixes.** Suggested remediations must specify exactly what to change, in
  which file, at which line. Include before/after code snippets when helpful.
- **Never fabricate errors.** Only report errors that actually appear in captured
  output. If a command produces no errors, say so.
- **Graceful degradation.** If a headless nvim command hangs (30s timeout) or fails,
  note it in findings and continue with remaining diagnostics. Never block on a
  single failing command.
- **Never skip a gate.** Always pause at Question gates and wait for user input before
  proceeding.
- **Never act without user confirmation.** Do not begin deep analysis until the user
  selects which categories to investigate.
- **Respect the config structure.** The neovim config is deployed via `xdg.configFile`
  from `configs/neovim/` in the nix config repo. Always reference files relative to
  the repo root, not `~/.config/nvim/`.
- **Stderr is signal.** In headless mode, most neovim errors go to stderr. Always
  capture and analyze stderr output — do not discard it.

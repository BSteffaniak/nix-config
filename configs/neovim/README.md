# Neovim

This is the portable Lua configuration deployed by
`home/modules/editors/neovim.nix`. Edit this repository, not the generated files
in `~/.config/nvim`.

## Resource policy

Rust uses **light** analysis by default. Opening/saving a Rust file does not run
Cargo check or Clippy, build scripts, or proc macros. rust-analyzer still loads
Cargo metadata and indexes source/dependencies; light mode is not zero-cost.

- `:RustMode off` / `:RustLspStop`: stop Rust LSP and prevent auto-attachment.
- `:RustMode light` / `:RustLspStart`: inexpensive analysis, two analysis threads,
  no cache priming, no automatic checks.
- `:RustMode full`: opt into build scripts/proc macros. Checks are still manual.
- `:RustMode`: show the current mode.
- `:RustCheck [cargo arguments]`: explicitly run `cargo check --jobs 2`.
- `:RustClippy [cargo arguments]`: explicitly run `cargo clippy --jobs 2`.
- `:RustCancel`: stop the active check job. Terminal output stays visible.

Use `NVIM_RUST_MODE=off nvim` for large workspaces where opening a file must not
start Rust analysis. Set `myConfig.editors.neovim.rust.mode = "off"` in the
host's `home.nix` to make this permanent. Modes are editor-wide, not per buffer.
Full mode can execute project build scripts; enable it only for trusted code.
Rustfmt remains available through the LSP without invoking Cargo checks.

Rust deliberately uses a direct rust-analyzer process, **not lspmux**: analysis
modes cannot mutate another editor's shared server and the process exits with
Neovim. Existing lspmux services/configuration remain available to other
clients;
existing shared processes are not stopped by deploying this configuration.

Files over 1 MiB or 20,000 lines skip automatic LSP, Tree-sitter, illumination,
and completion. Spell checking is enabled only for prose. Inlay hints are
opt-in with normal-mode Ctrl-Space; insert-mode Ctrl-Space triggers completion.
Java disables automatic builds and source downloads. ElixirLS disables automatic
builds, dependency fetching, and Dialyzer.

## Plugins and tooling

Only the colorscheme, Tree-sitter, and Lazy load at empty startup. Pickers,
completion, database tools, and language-specific plugins load when used.
Tree-sitter remains eager as required by upstream. fzf-lua owns pickers;
Gitsigns owns gutter signs and exposes on-demand blame via
`:lua require('gitsigns').blame_line()`.

Native Neovim provides commenting (`gc`), snippets, hover (`K`), and signature
help (Ctrl-Enter). Existing custom movement keys are preserved. Session loading
is `<leader>sl`; `<leader>l` retains the relative-number toggle. Diagnostics use
`gL` (fzf-lua) and `gt` (Trouble).

Formatting chooses one provider per buffer: none-ls external tools, Biome, then
other language servers; TypeScript's formatter does not compete. Prettierd and
ESLint stand aside in Biome projects. `b:disable_autoformat` disables save-time
formatting. ESLint/Selene require project configuration; other external tools
are registered only if installed. Restart Neovim after changing the tool PATH.

Nix/project environments own executables on Nix hosts. No Mason plugins or
installers run there. Standalone users can explicitly install tools with
`:Mason`; opening a buffer never installs servers or formatters. Optional
integrations retain the host plugin flags. Supermaven starts only on insert;
disable its host flag if you do not want its agent at all.

## Installation and updates

The current pinned Tree-sitter requires **Neovim >= 0.12** and tree-sitter-cli

> = 0.26.1. The flake's stable Neovim is currently 0.11.7, so existing nightly
> host
> selections are retained rather than making an incompatible downgrade.

1. Deploy with Home Manager/Nix (build and review with `./rebuild.sh --diff`
   before switching), or place this directory at `~/.config/nvim` standalone.
2. Install prerequisites explicitly: Neovim, Git, Python 3, tree-sitter-cli, a C
   compiler, curl, and tar. Provide language tools through Nix/project environments
   or Mason as appropriate.
3. Run `~/.config/nvim/install.sh restore` to install/restore pinned plugins.
4. Install only needed parsers explicitly, e.g.
   `:lua require('nvim-treesitter').install({'rust', 'lua', 'nix', 'tsx'})`.
   `treesitterHypr` registers the `hyprlang` filetype; install its parser explicitly.

Startup performs no Git clone, plugin installation, update check, or parser
installation. Missing plugins require the explicit restore step. Plugin build
hooks can download/build artifacts during that maintenance step, not opening a
file. Some optional plugins also manage their own runtime binaries.

`lazy-lock.json` pins the installed plugin revisions audited during this
cleanup;
this is intentionally not a wholesale plugin upgrade. Nix deploys the immutable
seed, while Lazy uses a writable copy under `stdpath('state')`. Run
`install.sh restore` after deploying changed pins. To update deliberately, run
`install.sh update`, review/test, and copy the printed state lock back into this
repository's `configs/neovim/lazy-lock.json`. Avoid `:Lazy sync` if you want to
retain unused plugin checkouts; restoration does not delete them.

## Validation

Run `nvim --headless -l configs/neovim/tests/run.lua` from the repository root.
The test uses an isolated config/state/cache, existing plugin checkouts
read-only,
and fake language servers/tools; it does not run Cargo or change live servers.
It covers startup, lazy loading, resource modes, large files, mappings, and
multi-buffer formatting registration. Real project CPU/memory and full-mode
build behavior should be measured separately in a trusted representative
project.

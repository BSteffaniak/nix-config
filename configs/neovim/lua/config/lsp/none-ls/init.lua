local M = {}

local nls = require("null-ls")
local nls_utils = require("null-ls.utils")
local b = nls.builtins

local with_diagnostics_code = function(builtin)
  return builtin.with({
    diagnostics_format = "[SC#{c}] #{m}",
  })
end

local with_root_file = function(builtin, file)
  return builtin.with({
    condition = function(utils)
      return utils.root_has_file(file)
    end,
  })
end

local eslint_config_files = {
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.json",
  ".eslintrc.yml",
  ".eslintrc.yaml",
  ".eslintrc",
}

require("mason-null-ls").setup({
  -- Each of one of these needs to be added in the configuration for none-ls.nvim
  ensure_installed = {
    -- Diagnostics
    "hadolint",
    "markdownlint", -- This is both, formatter and diagnostics

    -- Formatters
    "black",
    "isort",
    "prettier",
    "stylua",

    -- Deprecated LSPs in none-ls plugin
    "beautysh",
    "eslint_d",
    "jq",
  },
})

local sources = {
  -- formatting
  b.formatting.nixfmt,
  b.formatting.prettierd,
  b.formatting.stylua,
  b.formatting.shfmt.with({ extra_args = { "-i", "4" } }),
  b.formatting.black.with({ extra_args = { "--fast" } }),
  b.formatting.isort,

  -- diagnostics
  b.diagnostics.tidy,
  b.diagnostics.write_good,
  with_root_file(b.diagnostics.selene, "selene.toml"),

  -- code actions
  b.code_actions.gitsigns,
  b.code_actions.gitrebase,

  -- hover
  b.hover.dictionary,

  -- Only enable eslint_d when the project actually has an eslint config.
  -- Without this gate, eslint_d falls back to the bundled eslint inside the
  -- read-only Nix store, can't write its `.eslint_d` port file there, and
  -- prints "Failed to start daemon – Error: Timed out waiting for config".
  with_root_file(require("none-ls.diagnostics.eslint_d"), eslint_config_files),
  with_root_file(require("none-ls.formatting.eslint_d"), eslint_config_files),
  with_root_file(require("none-ls.code_actions.eslint_d"), eslint_config_files),
  with_diagnostics_code(require("none-ls-shellcheck.diagnostics")),
  require("none-ls-shellcheck.code_actions"),
}

function M.setup(on_attach)
  nls.setup({
    -- debug = true,
    debounce = 150,
    save_after_format = false,
    sources = sources,
    on_attach = on_attach,
    root_dir = nls_utils.root_pattern(".git"),
  })
end

return M

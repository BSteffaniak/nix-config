local M = {}

function M.setup()
	local nls = require("null-ls")
	local b = nls.builtins
	local function project_has(names)
		return function(utils)
			return utils.root_has_file(names)
		end
	end
	local biome = { "biome.json", "biome.jsonc" }
	local eslint = {
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
	local sources = {}
	local function add(source, executable, opts)
		-- Tools are provided by Nix/the project environment or explicitly installed
		-- with :Mason. Never install anything while opening a buffer.
		if vim.fn.executable(executable) == 1 then
			table.insert(sources, source.with(opts or {}))
		end
	end
	add(b.formatting.nixfmt, "nixfmt")
	add(b.formatting.prettierd, "prettierd", {
		condition = function(utils)
			return not utils.root_has_file(biome)
		end,
	})
	add(b.formatting.stylua, "stylua")
	add(b.formatting.shfmt, "shfmt", { extra_args = { "-i", "4" } })
	add(b.formatting.black, "black", { extra_args = { "--fast" } })
	-- isort and black are not competing LSP formatters: none-ls runs the chain.
	add(b.formatting.isort, "isort")
	add(b.diagnostics.selene, "selene", { condition = project_has({ "selene.toml" }) })
	if vim.fn.executable("eslint_d") == 1 then
		for _, method in ipairs({ "diagnostics", "formatting", "code_actions" }) do
			add(require("none-ls." .. method .. ".eslint_d"), "eslint_d", {
				condition = function(utils)
					return utils.root_has_file(eslint) and not utils.root_has_file(biome)
				end,
			})
		end
	end
	if vim.fn.executable("shellcheck") == 1 then
		add(require("none-ls-shellcheck.diagnostics"), "shellcheck")
		add(require("none-ls-shellcheck.code_actions"), "shellcheck")
	end
	nls.setup({
		debounce = 500,
		update_in_insert = false,
		sources = sources,
		should_attach = function(bufnr)
			return not require("bsteffaniak.performance").is_large(bufnr)
		end,
	})
end

return M

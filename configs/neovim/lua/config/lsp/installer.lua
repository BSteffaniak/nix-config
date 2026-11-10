local M = {}

function M.setup()
	vim.lsp.config("*", {
		capabilities = {
			textDocument = {
				completion = {
					completionItem = {
						snippetSupport = true,
						resolveSupport = { properties = { "documentation", "detail", "additionalTextEdits" } },
					},
				},
			},
		},
	})
	local host = require("bsteffaniak.host")
	local servers = {
		astro = {},
		gopls = {},
		html = {},
		jsonls = {},
		pyright = {},
		lua_ls = { settings = { Lua = { diagnostics = { globals = { "vim" } } } } },
		ts_ls = {},
		kotlin_language_server = {},
		svelte = {},
		bashls = {},
		clangd = { filetypes = { "c", "cpp", "objc", "objcpp", "cuda" } },
		csharp_ls = {},
		taplo = {},
		nil_ls = {},
		buf_ls = {},
		terraformls = {},
		biome = {},
	}
	if host.plugins.elixir then
		servers.elixirls = {
			settings = { elixirLS = {
				autoBuild = false,
				fetchDeps = false,
				dialyzerEnabled = false,
			} },
		}
	end
	for name, config in pairs(servers) do
		local base = vim.lsp.config[name]
		if base then
			local root = base.root_dir
			local function available(dir)
				local command = ({
					ts_ls = "typescript-language-server",
					biome = "biome",
					astro = "astro-ls",
					html = "vscode-html-language-server",
					jsonls = "vscode-json-language-server",
					pyright = "pyright-langserver",
					svelte = "svelteserver",
					csharp_ls = "csharp-ls",
					elixirls = "elixir-ls",
				})[name]
				if not command then
					return true
				end
				return vim.fn.executable(command) == 1
					or (dir and vim.fn.executable(dir .. "/node_modules/.bin/" .. command) == 1)
			end
			config.root_dir = function(bufnr, on_dir)
				if
					require("bsteffaniak.performance").is_large(bufnr)
					or (name == "gopls" and vim.fn.executable("go") ~= 1)
				then
					return
				end
				local function attach(dir)
					if available(dir) then
						on_dir(dir)
					end
				end
				if type(root) == "function" then
					root(bufnr, attach)
				else
					local dir = root or vim.fs.root(bufnr, base.root_markers or { ".git" })
					attach(dir or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
				end
			end
			vim.lsp.config(name, config)
			local cmd = vim.lsp.config[name].cmd
			if type(cmd) == "function" or (type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1) then
				vim.lsp.enable(name)
			end
		end
	end
	require("bsteffaniak.rust").configure()
end

return M

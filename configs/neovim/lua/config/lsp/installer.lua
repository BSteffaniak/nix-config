local M = {}

local function python_environment(bufnr)
	local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
	while dir do
		if vim.fn.executable(dir .. "/.venv/bin/python") == 1 then
			return dir
		end
		if vim.uv.fs_stat(dir .. "/.git") then
			return
		end
		local parent = vim.fs.dirname(dir)
		dir = parent ~= dir and parent or nil
	end
end

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
		pyright = { settings = { python = { analysis = { diagnosticMode = "openFilesOnly" } } } },
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
			if name == "pyright" then
				local before_init = base.before_init
				config.before_init = function(params, client_config)
					if before_init then
						before_init(params, client_config)
					end
					if client_config.root_dir then
						local python = client_config.root_dir .. "/.venv/bin/python"
						if vim.fn.executable(python) == 1 then
							-- Keep the settings table shared with the already-created client.
							client_config.settings = client_config.settings or {}
							client_config.settings.python = client_config.settings.python or {}
							client_config.settings.python.pythonPath = python
						end
					end
				end
			end
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
				local environment = name == "pyright" and python_environment(bufnr)
				if environment then
					attach(environment)
				elseif type(root) == "function" then
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

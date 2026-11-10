local function wait_for(predicate, label)
	assert(vim.wait(8000, predicate, 25), "Timed out: " .. label)
end
local function events()
	local values = {}
	if vim.fn.filereadable(vim.env.NVIM_TEST_EVENTS) == 1 then
		for _, line in ipairs(vim.fn.readfile(vim.env.NVIM_TEST_EVENTS)) do
			table.insert(values, vim.json.decode(line))
		end
	end
	return values
end
local function cargo_checks()
	local n = 0
	for _, event in ipairs(events()) do
		if
			event.process == "cargo" and vim.tbl_contains(event.args, "check")
			or event.process == "cargo" and vim.tbl_contains(event.args, "clippy")
		then
			n = n + 1
		end
	end
	return n
end
local function rust_client()
	for _, client in ipairs(vim.lsp.get_clients({ name = "rust_analyzer" })) do
		if client.initialized then
			return client
		end
	end
end
local ok, err = xpcall(function()
	local plugins = require("lazy.core.config").plugins
	local count = 0
	for _, plugin in pairs(plugins) do
		if plugin._.loaded then
			count = count + 1
		end
	end
	assert(count == 3, "Empty startup must load only three plugins, got " .. count)
	assert(not plugins["mason.nvim"] and not plugins["rustaceanvim"] and not plugins["telescope.nvim"])
	assert(not plugins["nvim-cmp"]._.loaded)
	assert(vim.fn.maparg("<leader>sl", "n") ~= "")
	assert(vim.fn.maparg("<leader>l", "n") ~= "")

	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/src/main.rs")
	if vim.env.NVIM_RUST_MODE == "off" then
		vim.wait(250)
		assert(not rust_client(), "Off mode started Rust LSP")
		assert(#events() == 0, "Off mode spawned a tool")
		vim.cmd.RustLspStart()
	end
	wait_for(rust_client, "Rust LSP attachment")
	local settings = rust_client().config.settings["rust-analyzer"]
	assert(settings.checkOnSave == false)
	assert(settings.cargo.buildScripts.enable == false)
	assert(settings.procMacro.enable == false)
	assert(settings.cachePriming.enable == false and settings.numThreads == 2)
	assert(rust_client().config.cmd[1] == "rust-analyzer")
	assert(cargo_checks() == 0, vim.json.encode(events()))
	local first = vim.api.nvim_get_current_buf()
	vim.cmd.write()
	vim.wait(150)
	assert(cargo_checks() == 0, "Saving invoked Cargo check")
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/src/other.rs")
	local second = vim.api.nvim_get_current_buf()
	wait_for(function()
		return #vim.lsp.get_clients({ bufnr = second, name = "rust_analyzer" }) == 1
	end, "second attachment")
	assert(#vim.api.nvim_get_autocmds({ group = "LspFormat", buffer = first }) == 1)
	assert(#vim.api.nvim_get_autocmds({ group = "LspFormat", buffer = second }) == 1)
	assert(vim.fn.maparg("K", "n", false, true).buffer == 1)
	vim.cmd.RustMode("full")
	wait_for(function()
		local c = rust_client()
		return c and c.config.settings["rust-analyzer"].procMacro.enable
	end, "full mode restart")
	assert(rust_client().config.settings["rust-analyzer"].checkOnSave == false)
	assert(cargo_checks() == 0)
	vim.cmd.RustLspStop()
	wait_for(function()
		return #vim.lsp.get_clients({ name = "rust_analyzer" }) == 0
	end, "Rust stopped")
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/src/main.rs")
	vim.wait(100)
	assert(not rust_client())
	vim.cmd.RustCheck()
	wait_for(function()
		return cargo_checks() == 1
	end, "explicit check")
	vim.wait(250)
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/src/main.rs")
	vim.cmd.RustClippy("--all-targets")
	wait_for(function()
		return cargo_checks() == 2
	end, "explicit clippy")

	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/large.rs")
	assert(require("bsteffaniak.performance").is_large(0))
	vim.cmd.RustMode("light")
	vim.wait(200)
	assert(#vim.lsp.get_clients({ bufnr = 0, name = "rust_analyzer" }) == 0, "Large file attached")
	vim.api.nvim_exec_autocmds("InsertEnter", {})
	assert(plugins["nvim-cmp"]._.loaded)
	assert(require("cmp").get_config().enabled() == false)
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/file.java")
	vim.wait(100)
	assert(not plugins["nvim-jdtls"], "Disabled Java plugin was enabled")
	for file, server in pairs({
		["test.lua"] = "lua_ls",
		["test.sh"] = "bashls",
		["test.nix"] = "nil_ls",
		["test.go"] = "gopls",
		["test.tsx"] = "ts_ls",
	}) do
		vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/" .. file)
		wait_for(function()
			for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0, name = server })) do
				if c.initialized then
					return true
				end
			end
		end, "language " .. server)
	end
	local python_clients = {}
	local original_cwd = vim.fn.getcwd()
	vim.cmd.cd(vim.env.NVIM_TEST_PROJECT .. "/python-b")
	for _, project in ipairs({ "python-a", "python-b", "python-missing", "python-broken" }) do
		local path = vim.env.NVIM_TEST_PROJECT .. "/" .. project
		vim.cmd.edit(path .. "/pkg/nested/test.py")
		local client
		wait_for(function()
			client = vim.lsp.get_clients({ bufnr = 0, name = "pyright" })[1]
			return client and client.initialized
		end, "Python " .. project)
		local has_environment = project == "python-a" or project == "python-b"
		assert(client.config.root_dir == (has_environment and path or path .. "/pkg"), "Wrong Python root")
		assert(client.settings.python.analysis.diagnosticMode == "openFilesOnly")
		if has_environment then
			assert(client.settings.python.pythonPath == path .. "/.venv/bin/python", "Wrong Python interpreter")
		else
			assert(not client.settings.python.pythonPath, "Broken/missing environment was selected")
		end
		python_clients[project] = client.id
	end
	vim.cmd.cd(original_cwd)
	assert(python_clients["python-a"] ~= python_clients["python-b"], "Python environments shared a client")
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/python-a/pkg/nested/large.py")
	vim.wait(100)
	assert(#vim.lsp.get_clients({ bufnr = 0, name = "pyright" }) == 0, "Large Python file attached")
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/test.astro")
	assert(vim.bo.filetype == "astro")
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/test.md")
	assert(vim.bo.filetype == "markdown" and vim.wo.spell)
	assert(plugins["markdown-preview.nvim"]._.loaded)
	vim.cmd.edit(vim.env.NVIM_TEST_PROJECT .. "/test.lua")
	assert(not vim.wo.spell, "Prose spell leaked to code")
	require("lazy").load({
		plugins = { "fzf-lua", "oil.nvim", "trouble.nvim", "maximize.nvim", "lualine.nvim", "which-key.nvim" },
	})
	assert(vim.fn.exists(":FzfLua") == 2 and vim.fn.exists(":Oil") == 2 and vim.fn.exists(":Trouble") == 2)
	Handle_save_session()
	Handle_load_session()
	vim.wait(200)
	local messages = vim.api.nvim_exec2("messages", { output = true }).output
	local lower = messages:lower()
	assert(not lower:find("error") and not lower:find("failed"), messages)
end, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	print("PASS: startup, Rust modes/checks, buffers, large files, optional plugins, completion, pickers")
	vim.cmd("qa!")
end

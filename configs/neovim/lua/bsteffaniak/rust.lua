local M = { mode = require("bsteffaniak.host").rust_mode }
local check_job
local restart_timer
local generation = 0

function M.settings(mode)
	local full = mode == "full"
	return {
		["rust-analyzer"] = {
			checkOnSave = false,
			check = { command = "check", allTargets = false, extraArgs = { "--jobs", "2" } },
			cargo = { allTargets = false, buildScripts = { enable = full } },
			procMacro = { enable = full },
			cachePriming = { enable = false },
			numThreads = 2,
		},
	}
end

function M.configure()
	local base = vim.lsp.config.rust_analyzer
	local root_dir = base.root_dir
	vim.lsp.config("rust_analyzer", {
		-- Deliberately direct: a per-editor mode must not reconfigure an lspmux
		-- instance shared with another editor. No daemon lifetime after exit.
		cmd = { "rust-analyzer" },
		settings = M.settings(M.mode),
		root_dir = function(bufnr, on_dir)
			if M.mode ~= "off" and not require("bsteffaniak.performance").is_large(bufnr) then
				local current_generation = generation
				root_dir(bufnr, function(dir)
					if generation == current_generation and M.mode ~= "off" and vim.lsp.is_enabled("rust_analyzer") then
						on_dir(dir)
					end
				end)
			end
		end,
	})
	M.configured = true
	if M.mode ~= "off" and vim.fn.executable("rust-analyzer") == 1 then
		vim.lsp.enable("rust_analyzer")
	end
end

function M.set_mode(mode)
	if not vim.tbl_contains({ "off", "light", "full" }, mode) then
		vim.notify("Rust mode must be off, light, or full", vim.log.levels.ERROR)
		return
	end
	generation = generation + 1
	if restart_timer then
		restart_timer:stop()
		restart_timer:close()
		restart_timer = nil
	end
	M.mode = mode
	-- This loads server definitions but does not start other filetypes' servers.
	if not M.configured then
		require("lazy").load({ plugins = { "nvim-lspconfig" } })
	end
	vim.lsp.enable("rust_analyzer", false)
	vim.lsp.config("rust_analyzer", { settings = M.settings(mode) })
	if mode ~= "off" and vim.fn.executable("rust-analyzer") == 1 then
		-- Wait for old clients to exit before enabling the replacement, otherwise
		-- Neovim may reuse a client that is still shutting down.
		local timer = vim.uv.new_timer()
		restart_timer = timer
		local attempts = 0
		timer:start(
			0,
			50,
			vim.schedule_wrap(function()
				if timer:is_closing() then
					return
				end
				attempts = attempts + 1
				if attempts > 100 then
					timer:stop()
					timer:close()
					restart_timer = nil
					vim.notify("Rust LSP did not exit; retry :RustLspStart", vim.log.levels.WARN)
					return
				end
				if #vim.lsp.get_clients({ name = "rust_analyzer", _uninitialized = true }) == 0 then
					timer:stop()
					timer:close()
					restart_timer = nil
					if M.mode ~= "off" then
						vim.lsp.enable("rust_analyzer")
						vim.cmd("doautoall nvim.lsp.enable FileType")
					end
				end
			end)
		)
	end
	vim.notify("Rust mode: " .. mode .. "; Cargo checks remain manual")
end

local function check(command, args)
	if check_job and vim.fn.jobwait({ check_job }, 0)[1] == -1 then
		vim.notify("A Rust check is already running. Use :RustCancel first.", vim.log.levels.WARN)
		return
	end
	local root = vim.fs.root(0, "Cargo.toml")
	if not root or vim.fn.executable("cargo") ~= 1 then
		vim.notify("Rust checks require Cargo and a Cargo.toml ancestor", vim.log.levels.ERROR)
		return
	end
	local cmd = { "cargo", command, "--jobs", "2" }
	vim.list_extend(cmd, args)
	vim.cmd("botright new")
	check_job = vim.fn.jobstart(cmd, { cwd = root, term = true })
end

function M.setup_commands()
	vim.api.nvim_create_user_command("RustMode", function(opts)
		if opts.args == "" then
			vim.notify("Rust mode: " .. M.mode)
		else
			M.set_mode(opts.args)
		end
	end, {
		nargs = "?",
		complete = function()
			return { "off", "light", "full" }
		end,
	})
	vim.api.nvim_create_user_command("RustLspStart", function()
		M.set_mode(M.mode == "off" and "light" or M.mode)
	end, {})
	vim.api.nvim_create_user_command("RustLspStop", function()
		M.set_mode("off")
	end, {})
	for name, command in pairs({ RustCheck = "check", RustClippy = "clippy" }) do
		vim.api.nvim_create_user_command(name, function(opts)
			check(command, opts.fargs)
		end, { nargs = "*" })
	end
	vim.api.nvim_create_user_command("RustCancel", function()
		if check_job then
			vim.fn.jobstop(check_job)
		end
	end, {})
end

return M

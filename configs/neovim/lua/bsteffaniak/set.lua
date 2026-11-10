vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.number = true
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.fixendofline = false
vim.opt.scrolloff = 6
vim.opt.clipboard = "unnamedplus"
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.spelllang = "en_us"
vim.opt.spelloptions = "camel"
vim.opt.completeopt = "menu,menuone,noinsert,noselect"
vim.g.sessions_home_directory = vim.env.NVIM_SESSIONS_HOME_DIRECTORY
vim.g.mkdp_echo_preview_url = 1

vim.filetype.add({ extension = { flat = "flat", astro = "astro" } })
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("ProseOptions", { clear = true }),
	pattern = { "markdown", "text", "gitcommit" },
	callback = function()
		if not require("bsteffaniak.performance").is_large(0) then
			vim.opt_local.spell = true
			vim.opt_local.wrap = true
			vim.opt_local.linebreak = true
		end
	end,
})

require("bsteffaniak.keymap")

vim.api.nvim_create_user_command("ArgsGitChanges", function(opts)
	local result = vim.system({ "git", "diff", "--name-only", "--diff-filter=ACMR", "-z", "HEAD" }, { text = false })
		:wait()
	if result.code ~= 0 then
		vim.notify(result.stderr, vim.log.levels.ERROR)
		return
	end
	local files = {}
	for file in result.stdout:gmatch("[^%z]+") do
		if opts.args == "" or vim.fn.match(file, vim.fn.glob2regpat(opts.args)) >= 0 then
			table.insert(files, vim.fn.fnameescape(file))
		end
	end
	if #files == 0 then
		vim.notify("No matching git changes")
		return
	end
	vim.cmd("args " .. table.concat(files, " "))
end, { nargs = "?", desc = "Load tracked git changes into args" })

function SaveQuery()
	if require("bsteffaniak.host").plugins.dadbod then
		require("lazy").load({ plugins = { "vim-dadbod-ui" } })
		vim.cmd([[execute "normal! \<Plug>(DBUI_SaveQuery)"]])
	end
end

vim.diagnostic.config({
	float = { source = "always", border = "rounded", max_width = 80, header = "" },
	update_in_insert = false,
})

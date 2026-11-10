local host = require("bsteffaniak.host")
local plugins = {
	{
		"srcery-colors/srcery-vim",
		lazy = false,
		priority = 1000,
		config = function()
			vim.g.srcery_black = "#0C0B0900"
			vim.cmd.colorscheme("srcery")
		end,
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("config.lsp.installer").setup()
		end,
	},
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			attach_to_untracked = false,
			on_attach = function(bufnr)
				return not require("bsteffaniak.performance").is_large(bufnr)
			end,
		},
	},
	{ "folke/trouble.nvim", cmd = "Trouble", opts = {} },
	{
		"nvimtools/none-ls.nvim",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvimtools/none-ls-extras.nvim",
			"gbprod/none-ls-shellcheck.nvim",
		},
		config = function()
			require("config.lsp.none-ls").setup()
		end,
	},
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-buffer",
		},
		config = function()
			require("config.completion").setup()
		end,
	},
	{
		"ibhagwan/fzf-lua",
		cmd = "FzfLua",
		opts = {
			winopts = { fullscreen = true, preview = { title_pos = "left" } },
			grep = { rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob=!.git" },
		},
		dependencies = { "nvim-tree/nvim-web-devicons" },
	},
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			if host.plugins.treesitter_hypr then
				vim.filetype.add({ extension = { hypr = "hyprlang" } })
			end
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("TreesitterHighlight", { clear = true }),
				callback = function(args)
					if not require("bsteffaniak.performance").is_large(args.buf) then
						pcall(vim.treesitter.start, args.buf)
					end
				end,
			})
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		ft = "markdown",
		cmd = { "MarkdownPreview", "MarkdownPreviewToggle" },
		build = function()
			vim.fn["mkdp#util#install"]()
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = {
			sections = { lualine_c = { { "filename", path = 1 } }, lualine_x = { "lsp_status", "filetype" } },
		},
		dependencies = { "nvim-tree/nvim-web-devicons" },
	},
	{
		"rrethy/vim-illuminate",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("illuminate").configure({
				delay = 250,
				large_file_cutoff = 20000,
				should_enable = function(bufnr)
					return not require("bsteffaniak.performance").is_large(bufnr)
				end,
			})
		end,
	},
	{ "wesQ3/vim-windowswap", keys = { "<leader>ww", "<leader>yw", "<leader>pw" } },
	{ "BSteffaniak/maximize.nvim", opts = {} },
	{ "tpope/vim-fugitive", cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gedit", "Gread", "Gwrite" } },
	{ "tpope/vim-capslock", cmd = "CapsLock" },
	{ "fabridamicelli/cronex.nvim", ft = { "sh", "bash", "yaml", "toml", "cron" }, opts = {} },
	{
		"stevearc/oil.nvim",
		cmd = "Oil",
		opts = {
			view_options = { show_hidden = true },
			keymaps = {
				["<Esc>"] = "actions.close",
				["<C-v>"] = { "actions.select", opts = { vertical = true } },
				["<C-x>"] = { "actions.select", opts = { horizontal = true } },
			},
		},
		dependencies = { { "echasnovski/mini.icons", opts = {} } },
	},
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {},
		keys = {
			{
				"<leader>?",
				function()
					require("which-key").show({ global = false })
				end,
				desc = "Buffer keymaps",
			},
		},
	},
	{ "mason-org/mason.nvim", enabled = host.tool_provider == "mason", cmd = "Mason", opts = {} },
	{ "mfussenegger/nvim-jdtls", enabled = host.plugins.jdtls, ft = "java" },
	{ "elixir-editors/vim-elixir", enabled = host.plugins.elixir, ft = { "elixir", "eelixir", "heex" } },
	{ "ionide/Ionide-vim", enabled = host.plugins.ionide, ft = { "fsharp" } },
	{ "tpope/vim-dadbod", enabled = host.plugins.dadbod, cmd = "DB" },
	{
		"kristijanhusak/vim-dadbod-ui",
		enabled = host.plugins.dadbod,
		cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
		dependencies = { "tpope/vim-dadbod" },
	},
	{
		"supermaven-inc/supermaven-nvim",
		enabled = host.plugins.supermaven,
		event = "InsertEnter",
		opts = {
			keymaps = { accept_suggestion = "<A-Tab>", clear_suggestion = "<A-Enter>" },
			condition = function()
				return require("bsteffaniak.performance").is_large(0)
			end,
		},
	},
	{ "github/copilot.vim", enabled = host.plugins.copilot, event = "InsertEnter" },
	{
		"yetone/avante.nvim",
		enabled = host.plugins.avante,
		cmd = { "AvanteAsk", "AvanteToggle", "AvanteEdit" },
		build = "make",
		opts = { provider = "openai", selector = { provider = "fzf_lua" } },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"ibhagwan/fzf-lua",
		},
	},
}

require("lazy").setup(plugins, {
	defaults = { lazy = true },
	-- Nix deploys this immutable seed; :Lazy update writes a writable state lock.
	lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
	install = { missing = false },
	checker = { enabled = false },
	change_detection = { notify = false },
})

local M = {}
function M.setup()
	local cmp = require("cmp")
	cmp.setup({
		enabled = function()
			return not require("bsteffaniak.performance").is_large(0)
		end,
		preselect = cmp.PreselectMode.None,
		snippet = {
			expand = function(args)
				vim.snippet.expand(args.body)
			end,
		},
		mapping = {
			["<C-p>"] = cmp.mapping.select_prev_item(),
			["<C-n>"] = cmp.mapping.select_next_item(),
			["<S-Tab>"] = cmp.mapping.select_prev_item(),
			["<Tab>"] = cmp.mapping.select_next_item(),
			["<C-d>"] = cmp.mapping.scroll_docs(-4),
			["<C-f>"] = cmp.mapping.scroll_docs(4),
			["<C-Space>"] = cmp.mapping.complete(),
			["<C-e>"] = cmp.mapping.close(),
			["<CR>"] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true }),
		},
		sources = {
			{ name = "nvim_lsp" },
			{ name = "path" },
			{
				name = "buffer",
				option = {
					get_bufnrs = function()
						return require("bsteffaniak.performance").is_large(0) and {}
							or { vim.api.nvim_get_current_buf() }
					end,
				},
			},
		},
	})
end
return M

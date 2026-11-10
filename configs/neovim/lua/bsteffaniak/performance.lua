local M = {}
M.max_bytes = 1024 * 1024
M.max_lines = 20000

function M.is_large(bufnr)
	bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
	return vim.b[bufnr].large_file == true or vim.api.nvim_buf_line_count(bufnr) > M.max_lines
end

function M.setup()
	local group = vim.api.nvim_create_augroup("LargeFiles", { clear = true })
	vim.api.nvim_create_autocmd("BufReadPre", {
		group = group,
		callback = function(args)
			local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(args.buf))
			vim.b[args.buf].large_file = stat ~= nil and stat.size > M.max_bytes
		end,
	})
	vim.api.nvim_create_autocmd({ "BufReadPost", "FileType" }, {
		group = group,
		callback = function(args)
			if M.is_large(args.buf) then
				vim.b[args.buf].large_file = true
				vim.bo[args.buf].syntax = "OFF"
				vim.bo[args.buf].swapfile = false
				vim.bo[args.buf].undofile = false
				vim.bo[args.buf].spellcapcheck = ""
				for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
					vim.wo[win].spell = false
				end
			end
		end,
	})
end

return M

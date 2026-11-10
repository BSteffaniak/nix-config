local M = {}
local format_group = vim.api.nvim_create_augroup("LspFormat", { clear = true })

function M.format(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	if require("bsteffaniak.performance").is_large(bufnr) then
		return
	end
	local method = opts.range and "textDocument/rangeFormatting" or "textDocument/formatting"
	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
	-- One formatter, deterministically: external formatters, then Biome, then
	-- native language servers. TypeScript never competes with prettier/Biome.
	local priority = { ["null-ls"] = 1, biome = 2, ts_ls = 100 }
	table.sort(clients, function(a, b)
		local ap, bp = priority[a.name] or 10, priority[b.name] or 10
		return ap == bp and a.name < b.name or ap < bp
	end)
	local client = clients[1]
	if client and client.name == "null-ls" then
		local methods = require("null-ls.methods")
		if #require("null-ls.sources").get_available(vim.bo[bufnr].filetype, methods.internal.FORMATTING) == 0 then
			client = clients[2]
		end
	end
	if not client or client.name == "ts_ls" then
		return
	end
	vim.lsp.buf.format(vim.tbl_extend("force", { bufnr = bufnr, id = client.id, timeout_ms = 2000 }, opts))
end

-- Kept for existing mappings and standalone filetype configuration.
_G.Format = M.format

function M.lsp_on_attach(client, bufnr)
	local function map(mode, key, action, desc)
		vim.keymap.set(mode, key, action, { buffer = bufnr, silent = true, desc = desc })
	end
	for key, direction in pairs({ ["[d"] = -1, ["]d"] = 1 }) do
		map("n", key, function()
			vim.diagnostic.jump({ count = direction, float = true })
		end, "Diagnostic")
	end
	for key, severity in pairs({ e = "ERROR", w = "WARN", i = "INFO" }) do
		for prefix, count in pairs({ ["["] = -1, ["]"] = 1 }) do
			map("n", prefix .. key, function()
				vim.diagnostic.jump({ count = count, severity = vim.diagnostic.severity[severity], float = true })
			end, severity .. " diagnostic")
		end
	end
	local bindings = {
		ga = { "textDocument/codeAction", vim.lsp.buf.code_action },
		K = { "textDocument/hover", vim.lsp.buf.hover },
		gd = { "textDocument/definition", vim.lsp.buf.definition },
		gD = { "textDocument/declaration", vim.lsp.buf.declaration },
		gR = { "textDocument/rename", vim.lsp.buf.rename },
		gh = {
			"textDocument/references",
			function()
				require("fzf-lua").lsp_references()
			end,
		},
	}
	for key, binding in pairs(bindings) do
		if client:supports_method(binding[1], bufnr) then
			map("n", key, binding[2], binding[1])
		end
	end
	map("n", "gl", vim.diagnostic.open_float, "Diagnostic detail")
	map("n", "gL", function()
		require("fzf-lua").diagnostics_document()
	end, "Buffer diagnostics")
	map("n", "gt", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics list")
	if client:supports_method("textDocument/signatureHelp", bufnr) then
		map({ "i", "n" }, "<C-Enter>", vim.lsp.buf.signature_help, "Signature help")
	end
	if client:supports_method("textDocument/inlayHint", bufnr) then
		map("n", "<C-Space>", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
		end, "Toggle inlay hints")
	end
	M.init_formatting(client, bufnr)
end

function M.init_formatting(client, bufnr)
	if not client:supports_method("textDocument/formatting", bufnr) then
		return
	end
	vim.keymap.set("n", "<Leader>a", M.format, { buffer = bufnr, desc = "Format" })
	vim.keymap.set("x", "<Leader>a", function()
		local first, last = vim.fn.line("v"), vim.fn.line(".")
		if first > last then
			first, last = last, first
		end
		M.format({
			range = {
				start = { first, 0 },
				["end"] = { last, #vim.api.nvim_buf_get_lines(bufnr, last - 1, last, false)[1] },
			},
		})
	end, { buffer = bufnr, desc = "Format selection" })
	vim.api.nvim_clear_autocmds({ group = format_group, buffer = bufnr })
	vim.api.nvim_create_autocmd("BufWritePre", {
		group = format_group,
		buffer = bufnr,
		callback = function()
			if not vim.b[bufnr].disable_autoformat then
				M.format()
			end
		end,
	})
end

function M.setup()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("LspKeys", { clear = true }),
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client then
				M.lsp_on_attach(client, args.buf)
			end
		end,
	})
end

return M

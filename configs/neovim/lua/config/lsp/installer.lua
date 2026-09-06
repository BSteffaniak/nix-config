local M = {}

-- Helper function to detect if Nix is available on the system
local function is_nix_system()
	return vim.fn.executable("nix") == 1
end

function M.setup(servers)
	-- Only use Mason for LSP installation if not on a Nix system
	-- On Nix systems, LSP servers are managed by Nix instead
	if not is_nix_system() then
		local mason_lspconfig = require("mason-lspconfig")
		local server_names = {}

		for server_name, _ in pairs(servers) do
			table.insert(server_names, server_name)
		end

		mason_lspconfig.setup({
			ensure_installed = server_names,
			automatic_installation = true,
		})
	end

	-- Configure and enable LSP servers (works with or without Mason)
	for server_name, config in pairs(servers) do
		local lsp_server_name = server_name
		if server_name == "tsserver" then
			lsp_server_name = "ts_ls"
		end

		vim.lsp.config[lsp_server_name] = vim.tbl_deep_extend("force", vim.lsp.config[lsp_server_name] or {}, config)
		vim.lsp.enable(lsp_server_name)
	end
end

return M

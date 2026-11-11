local M = {}

local ok, host = pcall(require, "host-config")
M.plugins = vim.tbl_extend("force", {
	supermaven = true,
	copilot = false,
	avante = false,
	jdtls = true,
	elixir = true,
	ionide = true,
	dadbod = true,
	treesitter_hypr = false,
}, ok and host.plugins or {})
M.tool_provider = ok and host.tool_provider or (vim.fn.executable("nix") == 1 and "nix" or "mason")
M.rust_mode = vim.env.NVIM_RUST_MODE or (ok and host.rust_mode) or "light"
assert(vim.tbl_contains({ "off", "light", "full" }, M.rust_mode), "Invalid NVIM_RUST_MODE")
M.python_lsp = vim.env.NVIM_PYTHON_LSP or (ok and host.python_lsp) or "ty"
assert(vim.tbl_contains({ "ty", "pyright" }, M.python_lsp), "Invalid NVIM_PYTHON_LSP")

return M

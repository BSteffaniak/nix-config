local M = {}

local methods = vim.lsp.protocol.Methods or {}
local method_formatting = methods.textDocument_formatting or "textDocument/formatting"
local method_range_formatting = methods.textDocument_rangeFormatting or "textDocument/rangeFormatting"

function Format()
  vim.lsp.buf.format({
    bufnr = vim.api.nvim_get_current_buf(),
    filter = function(c)
      return c.name ~= "tsserver"
    end,
    timeout_ms = 1000,
  })
end

local lsp_signature = require("lsp_signature")

vim.g.show_inlays = {}

function M.lsp_on_attach(client, bufnr)
  M.init_formatting(client, bufnr)

  local opts = { noremap = true, silent = true }

  vim.keymap.set("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  vim.keymap.set("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
  vim.keymap.set("n", "[e", "<cmd>lua vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.ERROR})<CR>", opts)
  vim.keymap.set("n", "]e", "<cmd>lua vim.diagnostic.goto_next({severity = vim.diagnostic.severity.ERROR})<CR>", opts)
  vim.keymap.set("n", "[w", "<cmd>lua vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.WARN})<CR>", opts)
  vim.keymap.set("n", "]w", "<cmd>lua vim.diagnostic.goto_next({severity = vim.diagnostic.severity.WARN})<CR>", opts)
  vim.keymap.set("n", "[i", "<cmd>lua vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.INFO})<CR>", opts)
  vim.keymap.set("n", "]i", "<cmd>lua vim.diagnostic.goto_next({severity = vim.diagnostic.severity.INFO})<CR>", opts)
  vim.keymap.set("n", "ga", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
  vim.keymap.set("n", "K", lsp_signature.toggle_float_win, opts)
  vim.keymap.set("n", "gh", "<cmd>Telescope lsp_references<CR>", opts)
  vim.keymap.set({ "i", "n", "v" }, "<c-Enter>", lsp_signature.toggle_float_win, opts)
  vim.keymap.set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  vim.keymap.set("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  vim.keymap.set("n", "gR", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  vim.keymap.set("n", "gl", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
  vim.keymap.set("n", "gL", "<cmd>Telescope diagnostics<CR>", opts)
  vim.keymap.set("n", "gt", "<cmd>TroubleToggle<CR>", opts)

  local show_inlays = vim.g.show_inlays
  show_inlays[bufnr] = true
  vim.g.show_inlays = show_inlays
  vim.lsp.inlay_hint.enable(vim.g.show_inlays[bufnr], { bufnr = bufnr })

  vim.keymap.set({ "n", "i", "v" }, "<c-Space>", function()
    local current_buf = vim.api.nvim_get_current_buf()
    show_inlays = vim.g.show_inlays
    show_inlays[current_buf] = not show_inlays[current_buf]
    vim.g.show_inlays = show_inlays
    local show = vim.g.show_inlays[current_buf]
    vim.lsp.inlay_hint.enable(show, { bufnr = current_buf })
  end, opts)

  -- format on save
  if client:supports_method(method_formatting, bufnr) then
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("Format", { clear = true }),
      buffer = bufnr,
      callback = Format,
    })
  end
end

function M.init_formatting(client, bufnr)
  if client:supports_method(method_formatting, bufnr) then
    vim.keymap.set("n", "<Leader>a", Format, { buffer = bufnr, desc = "[lsp] format" })
  end

  if client:supports_method(method_range_formatting, bufnr) then
    vim.keymap.set({ "x", "v" }, "<Leader>a", Format, { buffer = bufnr, desc = "[lsp] range format" })
  else
    -- print("odusnt support range formatting")
  end
end

return M

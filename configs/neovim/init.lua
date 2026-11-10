vim.g.mapleader = " "
vim.keymap.set("n", "<Space>", "<Nop>", { silent = true })
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("bsteffaniak.performance").setup()
require("bsteffaniak.lsp").setup()
require("bsteffaniak.rust").setup_commands()
require("bsteffaniak.set")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.notify("lazy.nvim is not installed. See the Neovim README bootstrap instructions.", vim.log.levels.WARN)
	return
end
vim.opt.rtp:prepend(lazypath)

-- Seed the writable state lock from the versioned, Nix-managed lockfile.
local seed = vim.fn.stdpath("config") .. "/lazy-lock.json"
local lock = vim.fn.stdpath("state") .. "/lazy-lock.json"
vim.fn.mkdir(vim.fn.stdpath("state"), "p")
if vim.uv.fs_stat(seed) and not vim.uv.fs_stat(lock) then
	vim.fn.writefile(vim.fn.readfile(seed), lock)
end
require("bsteffaniak.lazy")

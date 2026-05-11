require("bsteffaniak/savesession")

local key_opts = { noremap = true }

vim.keymap.set({ "n", "v" }, "gm", "m")
vim.keymap.set({ "n", "v" }, "m", "n")
vim.keymap.set({ "n", "v" }, "M", "N")
vim.keymap.set({ "n", "v" }, "h", "<left>", key_opts)
vim.keymap.set({ "n", "v" }, "t", "<down>", key_opts)
vim.keymap.set({ "n", "v" }, "n", "<up>", key_opts)
vim.keymap.set({ "n", "v" }, "s", "<right>", key_opts)
vim.keymap.set({ "n", "v" }, "<Leader>a", ":lua Format()<Enter>", key_opts)
vim.keymap.set("n", "<Leader>o", "o<Esc>", key_opts)
vim.keymap.set("n", "<Leader>O", "O<Esc>", key_opts)
vim.keymap.set("n", "<Leader>e", ":FzfLua git_files<Enter>", key_opts)
vim.keymap.set("n", "<Leader><Leader>", ":FzfLua files<Enter>", key_opts)
vim.keymap.set("n", "<Leader>t", function()
  local cwd = vim.fn.getcwd()
  require("oil").open_float(cwd)
end, key_opts)
vim.keymap.set("n", "<Leader>g", ":Oil --float<Enter>", key_opts)
-- vim.keymap.set("n", "<Leader>r", ':lua require("spectre").toggle()<Enter>', key_opts)
vim.keymap.set("n", "<Leader>f", ":FzfLua lgrep_curbuf<Enter>", key_opts)
vim.keymap.set("n", "<Leader>'", ":FzfLua live_grep<Enter>", key_opts)
vim.keymap.set("n", "<Leader>b", ":FzfLua live_grep resume=true<Enter>", key_opts)
vim.keymap.set("n", "<Leader>s", Handle_save_session, key_opts)
vim.keymap.set("n", "<Leader>S", ":mksession! ~/", key_opts)
vim.keymap.set("n", "<Leader>q", Handle_save_and_quit, key_opts)
vim.keymap.set("n", "<Leader>Q", Handle_force_save_and_quit, key_opts)
vim.keymap.set("n", "<Leader>l", Handle_load_session, key_opts)
vim.keymap.set("n", "<Leader>L", ":source ~/", key_opts)
vim.keymap.set("n", "<Leader>;", "@:", key_opts)
vim.keymap.set({ "n", "v", "i" }, "<M-ScrollWheelUp>", "<ScrollWheelLeft>", key_opts)
vim.keymap.set({ "n", "v", "i" }, "<M-ScrollWheelDown>", "<ScrollWheelRight>", key_opts)
vim.keymap.set({ "n", "v" }, ";", "l", key_opts)
vim.keymap.set({ "n", "v" }, "l", "k", key_opts)
vim.keymap.set({ "n", "v" }, "k", "j", key_opts)
vim.keymap.set({ "n", "v" }, "j", "h", key_opts)
vim.keymap.set({ "n", "v", "i" }, "<c-w>;", "<c-w><right>", key_opts)
vim.keymap.set({ "n", "v", "i" }, "<c-w>l", "<c-w><up>", key_opts)
vim.keymap.set({ "n", "v", "i" }, "<c-w>k", "<c-w><down>", key_opts)
vim.keymap.set({ "n", "v", "i" }, "<c-w>j", "<c-w><left>", key_opts)
vim.keymap.set({ "n", "v" }, "<Leader>.u", ":GitGutterUndoHunk<Enter>", key_opts)
vim.keymap.set({ "n", "v" }, "<Leader>.]", ":GitGutterNextHunk<Enter>", key_opts)
vim.keymap.set({ "n", "v" }, "<Leader>.[", ":GitGutterPrevHunk<Enter>", key_opts)
vim.keymap.set({ "n", "v" }, "<Leader>.h", ":0Gclog<Enter>", key_opts)
vim.keymap.set("n", "H", "<c-o>", key_opts)
vim.keymap.set("n", "S", "<c-i>", key_opts)
vim.keymap.set("v", "<Enter>", '"+y', key_opts)
vim.keymap.set({ "n", "v" }, "g#", function()
  vim.cmd(vim.api.nvim_replace_termcodes("normal gm`", true, true, true))
  vim.cmd("keepjumps normal! #``")
end)
vim.keymap.set("n", "YY", '"+yy', key_opts)

vim.keymap.set({ "n", "v" }, "t", function()
  return vim.v.count > 0 and "j" or "gj"
end, { expr = true, noremap = true })
vim.keymap.set({ "n", "v" }, "n", function()
  return vim.v.count > 0 and "k" or "gk"
end, { expr = true, noremap = true })
vim.keymap.set({ "n", "v" }, "k", function()
  return vim.v.count > 0 and "j" or "gj"
end, { expr = true, noremap = true })
vim.keymap.set({ "n", "v" }, "l", function()
  return vim.v.count > 0 and "k" or "gk"
end, { expr = true, noremap = true })

local maximize = require("maximize")

vim.keymap.set({ "n", "v" }, "<Leader><Tab>", function()
  maximize.restore()
  vim.cmd(vim.api.nvim_replace_termcodes("normal <c-w>w", true, true, true))
  maximize.maximize()
end, key_opts)

vim.keymap.set({ "n", "v" }, "<Leader>l", function()
  vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, key_opts)

vim.keymap.set({ "n", "v" }, "<Leader>j", function()
  local so = vim.opt.scrolloff:get()

  if so == 0 then
    vim.opt.scrolloff = vim.g.lastscrolloff
  else
    vim.g.lastscrolloff = so
    vim.opt.scrolloff = 0
  end
end, key_opts)

vim.keymap.set({ "n", "v" }, "<Leader>k", function()
  local so = vim.opt.scrolloff:get()

  if so == 999 then
    vim.opt.scrolloff = vim.g.lastscrolloff
  else
    vim.g.lastscrolloff = so
    vim.opt.scrolloff = 999
  end
end, key_opts)

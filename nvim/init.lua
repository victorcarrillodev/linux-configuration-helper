-- Líder: Espacio
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Opciones básicas tipo editor de código
local o = vim.opt
o.number = true
o.relativenumber = true
o.mouse = "a"
o.clipboard = "unnamedplus"
o.termguicolors = true
o.signcolumn = "yes"
o.cursorline = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.splitright = true
o.splitbelow = true
o.undofile = true
o.updatetime = 250
o.scrolloff = 8
o.laststatus = 3 -- una sola barra de estado abajo
o.showmode = false
o.wrap = false

-- Atajos generales
local map = vim.keymap.set
map("n", "<C-s>", "<cmd>w<cr>", { desc = "Guardar" })
map("i", "<C-s>", "<esc><cmd>w<cr>", { desc = "Guardar" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>")
map("n", "<C-h>", "<C-w>h")
map("n", "<C-l>", "<C-w>l")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Siguiente pestaña" })
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Pestaña anterior" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Cerrar pestaña" })

-- Instalar lazy.nvim (gestor de plugins) si no existe
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  install = { colorscheme = { "vscode" } },
  checker = { enabled = false },
  change_detection = { notify = false },
})

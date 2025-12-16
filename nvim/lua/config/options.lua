-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Line numbers: use absolute numbers instead of relative
vim.opt.number = true -- Show line numbers
vim.opt.relativenumber = false -- Disable relative line numbers (use absolute)

vim.opt.showtabline = 2 -- Always show tab line
vim.opt.tabpagemax = 50 -- Maximum number of tabs

-- Configure tab behavior
vim.opt.autowrite = true -- Don't auto-save when switching
vim.opt.confirm = true -- Ask for confirmation before abandoning unsaved changes

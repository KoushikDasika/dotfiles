-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Line numbers: use absolute numbers instead of relative
vim.opt.number = true -- Show line numbers
vim.opt.relativenumber = false -- Disable relative line numbers (use absolute)

-- Tab management: open new files in new tabs instead of buffers
local bufnr = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(bufnr, './file')
vim.api.nvim_buf_call(bufnr, vim.cmd.edit)

vim.opt.showtabline = 2 -- Always show tab line
vim.opt.tabpagemax = 50 -- Maximum number of tabs

-- Configure tab behavior
vim.opt.hidden = true -- Allow switching between buffers with unsaved changes (needed for tabs)
vim.opt.autowrite = false -- Don't auto-save when switching
vim.opt.confirm = true -- Ask for confirmation before abandoning unsaved changes

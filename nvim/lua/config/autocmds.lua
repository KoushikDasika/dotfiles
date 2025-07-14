-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Force new files to open in new tabs
vim.api.nvim_create_autocmd("BufAdd", {
  callback = function()
    -- If this is a real file (not a terminal, help, etc.) and we're not already in the first tab
    if vim.bo.buftype == "" and vim.fn.tabpagenr() > 1 then
      vim.cmd("tabnew")
    end
  end,
})

-- Alternative: Override file opening commands to use tabs
vim.api.nvim_create_user_command("E", function(opts)
  vim.cmd("tabnew " .. (opts.args or ""))
end, { nargs = "?" })

vim.api.nvim_create_user_command("Edit", function(opts)
  vim.cmd("tabnew " .. (opts.args or ""))
end, { nargs = "?" })

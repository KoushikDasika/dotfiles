return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.format_on_save = function(bufnr)
        if vim.b[bufnr].autoformat == false then
          return false
        end
        return { timeout_ms = 500, lsp_fallback = true }
      end
      return opts
    end,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sh", "bash", "yaml", "yml" },
        callback = function()
          vim.b.autoformat = false
        end,
      })
    end,
  },
}

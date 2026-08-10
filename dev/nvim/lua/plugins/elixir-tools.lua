vim.lsp.config("dexter", {
  cmd = { "dexter", "lsp" },
  root_markers = { ".dexter/dexter.db", ".dexter.db", ".git", "mix.exs" },
  filetypes = { "elixir", "eelixir", "heex" },
  init_options = {
    followDelegates = true,
  },
})

vim.lsp.enable("dexter")

return {
  {
    "elixir-tools/elixir-tools.nvim",
    version = "*",
    -- event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
}

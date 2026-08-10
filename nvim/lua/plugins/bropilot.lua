return {
  {
    "meeehdi-dev/bropilot.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim",
    },
    opts = {
      provider = "gemini",
      api_key = vim.env.GEMINI_API_KEY,
      model = "gemini-2.0-flash",
      auto_suggest = true,
      excluded_filetypes = {},
      model_params = {
        num_predict = -1,
        temperature = 0,
        top_p = 0.95,
        stop = { "<|fim_pad|>", "<|endoftext|>", "\n\n" },
      },
      debounce = 500,
      keymap = {
        accept_word = "<C-Right>",
        accept_line = "<S-Right>",
        accept_block = "<Tab>",
        suggest = "<C-Down>",
      },
    },
  },
}

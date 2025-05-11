require("bropilot").setup({
  provider = "ollama",
  auto_suggest = true,
  excluded_filetypes = {},
  model = "qwen3:0.6b",
  model_params = {
    num_ctx = 32768,
    num_predict = -2,
    temperature = 0.2,
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
  ollama_url = "http://localhost:11434/api",
})

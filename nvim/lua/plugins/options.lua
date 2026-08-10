return {
  -- add gruvbox
  { "ellisonleao/gruvbox.nvim" },
  {
    "folke/trouble.nvim",
    -- opts will be merged with the parent spec
    opts = { use_diagnostic_signs = true },
  },

  -- disable trouble
  { "folke/trouble.nvim", enabled = false },

  -- override nvim-cmp and add cmp-emoji
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      table.insert(opts.sources, { name = "emoji" })
    end,
  },

  -- change some telescope options and a keymap to browse plugin files
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- add a keymap to browse plugin files
      -- stylua: ignore
      {
        "<leader>fp",
        function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
        desc = "Find Plugin File",
      },
    },
    -- change some options
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },

  -- add tsserver and setup with typescript.nvim instead of lspconfig
  --{
  --  "nvim-treesitter/nvim-treesitter",
  --  dependencies = {
  --    "nvim-tree/nvim-web-devicons", -- Add nvim-web-devicons as a dependency
  --  },
  --  opts = {
  --    highlight = {
  --      enable = true,
  --      use_icons = {
  --        glyphs = {
  --          folder = {
  --            arrow_closed = "",
  --            arrow_open = "",
  --          },
  --          git = {
  --            unstaged = "✗",
  --            staged = "✓",
  --            unmerged = "",
  --            renamed = "➜",
  --            untracked = "★",
  --            deleted = "",
  --            ignored = "◌",
  --          },
  --        },
  --      },
  --    },
  --  },
  --},
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "jose-elias-alvarez/typescript.nvim",
    },
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- tsserver will be automatically installed with mason and loaded with lspconfig
        tsserver = {},
      },
      -- you can do any additional lsp server setup here
      -- return true if you don't want this server to be setup with lspconfig
      ---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
      setup = {
        -- example to setup with typescript.nvim
        tsserver = function(_, opts)
          require("typescript").setup({ server = opts })
          return true
        end,
        -- Specify * to use this function as a fallback for any server
        -- ["*"] = function(server, opts) end,
      },
    },
  },
  {
    "nvim-tree/nvim-web-devicons", -- Add nvim-web-devicons
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "flake8",
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    "neovim/nvim-lspconfig",
  },
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons", "nvim-mini/mini.icons" },
    opts = {},
    config = function()
      require("fzf-lua").setup({})
    end,
  },
}

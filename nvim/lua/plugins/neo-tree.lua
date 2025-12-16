return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    version = "2.9.0",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      -- Configure Neo-tree to use icons
      require("neo-tree").setup({
        default_component_config = {
          icons = {
            enable = true,
            use_icons = true,
            -- folder = {
            --   -- Define arrow and default folder icons
            --   arrow_open = "", -- Down arrow for open folders
            --   arrow_closed = "", -- Right arrow for closed folders
            --   default = "", -- Default folder icon
            -- },
            -- file = {
            --   -- Define default file icon
            --   default = "", -- Default file icon
            -- },
            -- Define specific icons for file types (optional)
            -- Example: { "txt" = "", "md" = "", "lua" = "" }
          },
        },
        window = {
          position = "left",
          width = 30,
        },
        filesystem = {
          follow_current_file = { enabled = true },
          use_libuv_file_watcher = true,
        },
      })
    end,
  },
}

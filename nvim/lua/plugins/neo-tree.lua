return {
  "neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true, -- hide filtered items on open
        hide_gitignored = false,
        hide_dotfiles = false,
        hide_by_name = {
          ".changeset",
          ".prettierrc.json",
        },
        never_show = { ".git" },
      },
    },
  },
}

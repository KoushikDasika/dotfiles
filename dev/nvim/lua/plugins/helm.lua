return {
  -- filetype detection + syntax for helm charts (retypes to ft=helm, detaches yamlls)
  { "towolf/vim-helm", ft = "helm" },

  -- helm language server on the `helm` filetype
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        helm_ls = {},
      },
    },
  },

  -- ensure the helm-ls binary is installed via mason
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "helm-ls")
    end,
  },
}

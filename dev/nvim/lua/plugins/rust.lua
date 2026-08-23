return {
  {
    "mrcjkb/rustaceanvim",
    -- rustaceanvim handles its own lazy loading via ftplugin
    lazy = false,
    -- clear LazyVim's ft-based loading
    ft = nil,
    opts = {
      server = {
        on_attach = function(_, bufnr)
          local map = function(key, cmd, desc)
            vim.keymap.set("n", key, function()
              vim.cmd.RustLsp(cmd)
            end, { desc = desc, buffer = bufnr })
          end

          -- keep LazyVim defaults
          map("<leader>cR", "codeAction", "Code Action")
          map("<leader>dr", "debuggables", "Rust Debuggables")

          -- Rust-specific keymaps (all under <leader>r)
          map("<leader>rr", "runnables", "Rust Runnables")
          map("<leader>re", "expandMacro", "Expand Macro")
          map("<leader>rx", "explainError", "Explain Error")
          map("<leader>rk", "openDocs", "Open Docs.rs")
          map("<leader>rp", "parentModule", "Parent Module")
          map("<leader>rc", "openCargo", "Open Cargo.toml")
          map("<leader>ra", { "hover", "actions" }, "Hover Actions")
          map("<leader>rj", "joinLines", "Join Lines (Rust)")
          map("<leader>rm", "moveItem down", "Move Item Down")
          map("<leader>rM", "moveItem up", "Move Item Up")

          -- Single test under cursor
          vim.keymap.set("n", "<leader>rt", function()
            vim.cmd.RustLsp({ "testables" })
          end, { desc = "Rust Testables", buffer = bufnr })

          -- Rust-aware join lines on J
          vim.keymap.set("n", "J", function()
            vim.cmd.RustLsp("joinLines")
          end, { desc = "Rust Join Lines", buffer = bufnr })
        end,
        default_settings = {
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = {
                enable = true,
              },
            },
            -- clippy catches more mistakes than rustc alone — great for learning
            check = {
              command = "clippy",
            },
            checkOnSave = true,
            diagnostics = {
              enable = true,
            },
            procMacro = {
              enable = true,
            },
            -- inlay hints: see types and parameter names inline
            inlayHints = {
              bindingModeHints = { enable = true },
              chainingHints = { enable = true },
              closingBraceHints = { enable = true, minLines = 10 },
              closureReturnTypeHints = { enable = "always" },
              lifetimeElisionHints = { enable = "skip_trivial" },
              parameterHints = { enable = true },
              reborrowHints = { enable = "always" },
              typeHints = { enable = true },
            },
            files = {
              exclude = {
                ".direnv",
                ".git",
                ".jj",
                ".github",
                ".gitlab",
                "bin",
                "node_modules",
                "target",
                "venv",
                ".venv",
              },
              watcher = "client",
            },
          },
        },
      },
    },
  },
}

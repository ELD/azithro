return {
  "mrcjkb/rustaceanvim",
  sem_version = "^6",
  ft = { "rust" },
  init = function()
    vim.g.rustaceanvim = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
            },
            check = {
              command = "clippy",
            },
            completion = {
              fullFunctionSignatures = {
                enable = true,
              },
            },
            diagnostics = {
              experimental = {
                enable = true,
              },
            },
            imports = {
              granularity = {
                group = "module",
              },
              prefix = "self",
            },
            inlayHints = {
              bindingModeHints = {
                enable = true,
              },
              closureReturnTypeHints = {
                enable = "with_block",
              },
              discriminantHints = {
                enable = "fieldless",
              },
              lifetimeElisionHints = {
                enable = "skip_trivial",
              },
              typeHints = {
                hideClosureInitialization = false,
              },
            },
            procMacro = {
              enable = true,
            },
          },
        },
      },
    }
  end,
}

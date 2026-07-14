vim.lsp.config("bashls", {})

vim.lsp.config("cssls", {})

vim.lsp.config("eslint", {
  settings = {
    format = false,
  },
})

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      analyses = {
        fieldalignment = true,
        nilness = true,
        shadow = true,
        unusedparams = true,
        unusedwrite = true,
        useany = true,
      },
      gofumpt = true,
      staticcheck = true,
      usePlaceholders = true,
    },
  },
})

vim.lsp.config("graphql", {})

vim.lsp.config("html", {})

vim.lsp.config("jsonls", {
  settings = {
    json = {
      validate = { enable = true },
    },
  },
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
    },
  },
})

vim.lsp.config("marksman", {})

vim.lsp.config("taplo", {})

vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      keyOrdering = false,
      validate = true,
    },
  },
})

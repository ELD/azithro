vim.diagnostic.config({
  float = {
    border = "rounded",
    source = true,
  },
  severity_sort = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  virtual_text = false,
})

local lsp_group = vim.api.nvim_create_augroup("azithro_lsp", { clear = true })
local highlight_group = vim.api.nvim_create_augroup("azithro_lsp_document_highlight", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    local bufnr = args.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "K", vim.lsp.buf.hover, "LSP Hover")
    map("n", "<leader>rn", vim.lsp.buf.rename, "LSP Rename")
    map({ "n", "x" }, "<leader>ca", function()
      local ok, tiny_code_action = pcall(require, "tiny-code-action")
      if ok then
        tiny_code_action.code_action()
      else
        vim.lsp.buf.code_action()
      end
    end, "LSP Code Action")
    map({ "n", "x" }, "<leader>cf", function()
      local ok, conform = pcall(require, "conform")
      if ok then
        conform.format({ bufnr = bufnr, async = true, lsp_format = "fallback" })
      else
        vim.lsp.buf.format({ bufnr = bufnr, async = true })
      end
    end, "LSP Format")
    map("n", "[d", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, "Previous Diagnostic")
    map("n", "]d", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, "Next Diagnostic")
    map("n", "<leader>cd", vim.diagnostic.open_float, "Line Diagnostic")
    map("n", "<leader>cq", vim.diagnostic.setloclist, "Diagnostics Location List")

    if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, bufnr) then
      pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
    end

    if client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, bufnr) then
      vim.api.nvim_clear_autocmds({ group = highlight_group, buffer = bufnr })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})

vim.api.nvim_create_autocmd("LspDetach", {
  group = lsp_group,
  callback = function(args)
    vim.api.nvim_clear_autocmds({ group = highlight_group, buffer = args.buf })
    vim.lsp.buf.clear_references()
  end,
})

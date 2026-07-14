# Azithro

A small Neovim distribution that uses `zpack.nvim` to wrap Neovim's native `vim.pack` package manager with lazy-loading niceties. The name comes from `Z-Pak`, the common name for Azithromycin antibiotics.

Azithro is aimed at day-to-day Rust, Go, TypeScript, API, and debugging workflows without becoming a large framework.

## Goals

- Keep the config readable and modular.
- Prefer focused plugins over all-in-one language bundles.
- Use Neovim's modern LSP configuration model.
- Provide a ready Rust, Go, and TypeScript editing baseline.
- Include formatting, linting, testing, DAP, Git, and HTTP tooling.
- Keep UI polish centered around `snacks.nvim`, `blink.cmp`, and `lualine.nvim`.

## Requirements

- Neovim 0.11+ with `vim.pack` support.
- A Nerd Font for icons and statusline glyphs.
- `git`, `curl`, and common build tools for language servers and Treesitter parsers.

Recommended external tools:

- Rust: `rustup`, `cargo`, `rustfmt`, `clippy`
- Go: `go`
- TypeScript: `node`, `npm`, `pnpm`, or `yarn`
- API/WebSocket: `websocat` or `wscat`

Most LSP servers, formatters, linters, and DAP adapters are installed through Mason.

## Structure

```text
init.lua
lua/config/
  autocmds.lua
  editor.lua
  keymaps.lua
  lsp.lua
lua/plugins/
  api.lua
  blink.lua
  conform.lua
  dap.lua
  gitsigns.lua
  lint.lua
  lualine.lua
  mason-tools.lua
  neotest.lua
  rust.lua
  snacks.lua
  treesitter.lua
  trouble.lua
  typescript.lua
  which-key.lua
```

## Language Support

### Rust

Rust support leans on `rustaceanvim` rather than a plain `rust_analyzer` setup.

- LSP: `rustaceanvim` with `rust-analyzer`
- Formatting: `rustfmt` through `conform.nvim`
- Checks: `clippy` via rust-analyzer settings
- Debugging: `codelldb` through `nvim-dap`
- Testing: `neotest-rust`
- Syntax: Treesitter `rust`

### Go

Go support intentionally uses a minimal, composable stack rather than a dedicated Go workflow plugin:

- LSP: `gopls`
- Formatting: `goimports` and `gofumpt` through `conform.nvim`
- Debugging: `delve` through `nvim-dap-go`
- Testing: `neotest-golang`
- Syntax: Treesitter parsers for `go`, `gomod`, `gosum`, and `gowork`

This keeps Go behavior aligned with the rest of the distro: LSP for language intelligence, Conform for formatting, DAP for debugging, and Neotest for tests.

Future expansion could add `ray-x/go.nvim` if Go-specific commands become important, such as struct tag editing, coverage helpers, `GoImpl`, `GoIfErr`, `GoModTidy`, or richer Go test commands.

### TypeScript

TypeScript support uses `typescript-tools.nvim` instead of directly enabling `ts_ls`.

- LSP: `typescript-tools.nvim`
- Linting: `eslint_d` through `nvim-lint`
- Formatting: `prettierd` or `prettier` through `conform.nvim`
- Debugging: `js-debug-adapter` through `nvim-dap`
- Testing: `neotest-vitest`
- Syntax: Treesitter `typescript`, `tsx`, and `javascript`

Useful TypeScript mappings:

- `<leader>co`: organize imports
- `<leader>cM`: add missing imports
- `<leader>cu`: remove unused
- `<leader>cF`: fix all
- `<leader>cT`: rename file

## LSP

Language servers are installed with `mason-lspconfig.nvim`.

Configured servers include:

- `bashls`
- `cssls`
- `eslint`
- `gopls`
- `graphql`
- `html`
- `jsonls`
- `lua_ls`
- `marksman`
- `rust_analyzer`
- `taplo`
- `ts_ls`
- `yamlls`

`rust_analyzer` and `ts_ls` are installed but excluded from automatic enabling because Rust and TypeScript are handled by `rustaceanvim` and `typescript-tools.nvim`.

LSP attach behavior lives in `lua/config/autocmds.lua` and provides buffer-local mappings for hover, rename, code actions, formatting, diagnostics, inlay hints, and document highlights.

## Formatting And Linting

Formatting uses `conform.nvim` with format-on-save and LSP fallback.

Formatters include:

- `rustfmt`
- `goimports`
- `gofumpt`
- `prettierd`
- `prettier`
- `stylua`
- `shfmt`
- `taplo`

Linting uses `nvim-lint`.

Linters include:

- `eslint_d`
- `shellcheck`
- `markdownlint-cli2`
- `hadolint`

Mason tool installation is configured in `lua/plugins/mason-tools.lua`.

## Debugging

DAP support uses:

- `nvim-dap`
- `nvim-dap-ui`
- `nvim-dap-virtual-text`
- `mason-nvim-dap.nvim`
- `nvim-dap-go`

Adapters:

- Rust: `codelldb`
- Go: `delve`
- JavaScript/TypeScript: `js-debug-adapter`

Debug mappings:

- `<leader>db`: toggle breakpoint
- `<leader>dB`: conditional breakpoint
- `<leader>dc`: continue
- `<leader>di`: step into
- `<leader>do`: step over
- `<leader>dO`: step out
- `<leader>dr`: REPL
- `<leader>dl`: run last
- `<leader>dt`: terminate
- `<leader>du`: toggle DAP UI

## Testing

Testing uses `neotest`.

Adapters:

- `neotest-rust`
- `neotest-golang`
- `neotest-vitest`

Test mappings:

- `<leader>tt`: run nearest test
- `<leader>tf`: run current file
- `<leader>td`: debug nearest test
- `<leader>ts`: toggle test summary
- `<leader>to`: open test output
- `<leader>tO`: toggle output panel
- `<leader>tw`: watch current file
- `<leader>tS`: stop test

## API And WebSocket Testing

HTTP/API testing uses `kulala.nvim` for `.http` and `.rest` files.

API mappings:

- `<leader>ar`: run request
- `<leader>aa`: run all requests
- `<leader>ap`: previous request
- `<leader>an`: next request
- `<leader>as`: show stats
- `<leader>at`: toggle view
- `<leader>ac`: copy request

WebSocket helpers open terminal clients through Snacks:

- `<leader>aw`: open `websocat`
- `<leader>aW`: open `wscat`

These helpers prompt for a URL and warn if the selected tool is missing from `PATH`.

## UI And Navigation

Core UI pieces:

- `snacks.nvim`: picker, dashboard, explorer, notifier, terminal, statuscolumn, scroll, words, zen mode
- `blink.cmp`: completion with VS Code-like behavior, icons, syntax-colored labels, docs, ghost text, and signature help
- `lualine.nvim`: global statusline with mode, file, Git, diagnostics, LSP clients, formatters, filetype, progress, and location
- `which-key.nvim`: leader-key discovery
- `trouble.nvim`: diagnostics, symbols, references, quickfix, and loclist views
- `aerial.nvim`: symbol outline
- `todo-comments.nvim`: TODO/FIXME/HACK/WARN/NOTE highlighting and navigation
- `gitsigns.nvim`: inline Git hunks, blame, preview, stage/reset, and hunk text objects

Common picker mappings:

- `<leader><space>`: smart file picker
- `<leader>/`: grep
- `<leader>,`: buffers
- `<leader>ff`: files
- `<leader>fg`: Git files
- `<leader>fr`: recent files
- `<leader>fp`: projects
- `<leader>e`: explorer

Git mappings:

- `<leader>gg`: Lazygit
- `<leader>gs`: Git status picker
- `<leader>gd`: Git diff picker
- `]h`: next hunk
- `[h`: previous hunk
- `<leader>ghp`: preview hunk
- `<leader>ghs`: stage hunk
- `<leader>ghr`: reset hunk

## Bootstrap

This config expects to be used as a Neovim config directory. On first start, `zpack.nvim` installs plugins through `vim.pack` and Mason installs configured language servers/tools/adapters.

For a quick startup check, run:

```sh
nvim --headless '+quit'
```

Use `:Mason` to inspect installed external tools.

## Notes

- `noice.nvim` was intentionally removed during cleanup; Snacks already handles the current notification/input/picker needs.
- `ts_ls` and `rust_analyzer` remain Mason-installed for availability but are not auto-enabled directly.
- Go is intentionally minimal for now; add `go.nvim` only if Go-specific commands become worth the extra surface area.

# Azithro

A small Neovim distribution that uses `zpack.nvim` to wrap Neovim's native `vim.pack` package manager with lazy-loading niceties. The name comes from `Z-Pak`, the common name for Azithromycin antibiotics.

Azithro is aimed at day-to-day Rust, Go, TypeScript, API, and debugging workflows without becoming a large framework.

See the [keymap cheatsheet](CHEATSHEET.md) for shortcuts grouped by workflow.

## Goals

- Keep the config readable and modular.
- Prefer focused plugins over all-in-one language bundles.
- Use Neovim's modern LSP configuration model.
- Provide a ready Rust, Go, and TypeScript editing baseline.
- Include formatting, linting, testing, DAP, Git, and HTTP tooling.
- Keep UI polish centered around `snacks.nvim`, `blink.cmp`, and `lualine.nvim`.

## Requirements

- Neovim 0.13+ with `vim.pack` and the `packlockfile` option (tested with pinned nightlies).
  Stable Neovim 0.12.5 does not provide the writable-lock support this config needs.
- A Nerd Font for icons and statusline glyphs.
- `git`, `curl`, the tree-sitter CLI, and common build tools for language servers and parsers.

Recommended external tools:

- Rust: `rustup`, `cargo`, `rustfmt`, `clippy`
- Go: `go`
- TypeScript: `node`, `npm`, `pnpm`, or `yarn`
- API/WebSocket: `websocat` or `wscat`

Standalone usage defaults to Mason: language servers are ensured automatically;
run `:MasonToolsInstall` explicitly for formatters, linters and debug adapters.
The [Home Manager module](nix/README.md) instead uses Nix-provided tools and does
not load Mason. Plugins remain managed by ZPack in either mode.

Implementation progress and cutover gates live in [NIX-READINESS.md](NIX-READINESS.md).

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
  blink/
  conform.lua
  dap.lua
  gitsigns.lua
  lint.lua
  lualine.lua
  mason-tools.lua
  neotest.lua
  rust.lua
  snacks.lua
  treesitter-manager.lua
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
- ESLint diagnostics and fixes: ESLint LSP (the single ESLint owner)
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

In standalone Mason mode, language servers are installed with
`mason-lspconfig.nvim`. Nix mode enables the configured servers directly, using
executables from the Neovim wrapper's PATH.

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

In Mason mode, `rust_analyzer` and `ts_ls` are installed but excluded from
automatic enabling. In Nix mode they are likewise not enabled directly: Rust
and TypeScript are handled by `rustaceanvim` and `typescript-tools.nvim`.

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

- `shellcheck`
- `markdownlint-cli2`
- `hadolint`

Mason tool installation is configured in `lua/plugins/mason-tools.lua`; the
Nix tool inventory lives in `nix/tools.nix`. JavaScript/TypeScript use ESLint LSP
for diagnostics and fixes instead of a second `eslint_d` process.

## Markdown

`markview.nvim` renders Markdown, Quarto, and R Markdown at startup, with hybrid
Insert-mode previews (the edited node remains raw). It also renders Markdown
LSP hovers/completion documentation, uses devicons for code-block labels, and
adds Blink callout/checkbox completions without replacing existing sources.
The existing Tree-sitter manager installs `markdown` and `markdown_inline`;
`html` and `yaml` cover embedded markup/frontmatter. `gx` is left unchanged.

All three extras are enabled: fenced code-block editing/creation, heading-level
changes, and checkbox toggling/state selection. Normal-mode mappings are
buffer-local to the supported Markdown filetypes under `<leader>m`:

- `mp` / `mP`: toggle current / all previews
- `ms`: toggle split preview
- `mh`: toggle hybrid mode
- `me` / `mc`: edit / create fenced code block
- `mx` / `mX`: toggle checkbox / choose state
- `m[` / `m]`: decrease / increase heading level

In the code-block editor, `<CR>` applies changes and `q` closes the float.

## Debugging

DAP support uses:

- `nvim-dap`
- `nvim-dap-ui`
- `nvim-dap-virtual-text`
- `mason-nvim-dap.nvim` (Mason mode only)
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

This config expects to be used as a Neovim config directory. On first start,
`vim.pack` installs the bundled lock entries, then ZPack loads enabled plugins.
Plugin repositories and native artifacts need writable user data and Git/network
access; Nix deploying the config does not preinstall those plugins.

In Mason mode, language servers are ensured automatically; run
`:MasonToolsInstall` for the other configured tools/adapters. Use `:Mason` to
inspect them. In Nix mode, install external tools through Home Manager; Mason
is not loaded and is not part of that workflow.

The `.envrc` creates a separate `azithro` development config link only when the
path is absent; it never replaces an existing link/directory. The eventual
Home Manager wrapper deliberately uses the `nvim` app namespace. See
[nix/README.md](nix/README.md) for editable/store-backed deployment.

## Runtime Settings

Settings are validated at startup; paths must be absolute. Home Manager sets
these on its Neovim wrapper, not globally in the shell.

| Environment variable | Default / purpose |
| --- | --- |
| `AZITHRO_TOOL_PROVIDER` | `mason`; select `nix` for externally provisioned tools |
| `AZITHRO_PACK_LOCK` | Unset: tracked config lock; override for immutable deployments |
| `AZITHRO_STITCHR_PATH` | Unset: disabled; local grammar checkout with `grammar.js` |
| `AZITHRO_EXPERIMENTAL_UI` | `1`; private UI API is guarded, `0` uses native UI |
| `AZITHRO_PROFILING` | `0`; enable ZPack loader/require profiling with `1` |
| `AZITHRO_AI_ENABLED` | `0`; opt into the OpenCode-backed `99` plugin with `1` |
| `AZITHRO_AI_MODEL` | Unset: provider/plugin default; optional explicit model |
| `AZITHRO_JS_DEBUG_COMMAND` | Nix mode: absolute executable taking a port argument |
| `AZITHRO_JS_DEBUG_SERVER` | Alternative: absolute JS server script, requiring Node |
| `AZITHRO_CODELLDB_COMMAND` | Nix mode: absolute adapter path, otherwise `codelldb` on PATH |
| `AZITHRO_LIBLLDB_PATH` | Optional explicit CodeLLDB shared-library path |

Boolean settings accept `1`, `0`, `true` or `false`. AI usage requires OpenCode
and configured provider credentials; scratch requests live in `./.azithro-tmp`
inside the current project. Add that directory to your project/global Git
ignore before enabling AI. Do not enable it for projects whose contents should
not be sent to the selected provider.

## Plugin Lock Workflow

The canonical manifest is the Git-tracked `nvim-pack-lock.json`. ZPack delegates
it to native `vim.pack`; there is no second ZPack lock/database in the reviewed
version. Plugin checkouts live under `stdpath("data")/site/pack/core/opt`; parser
output, caches and update logs also stay outside the config tree.

**Editable checkout:** run `:ZPack update`, review the lock diff, commit/push it,
then update the system flake's Azithro input with `nix flake update azithro`.
Plugin changes take full effect after restarting Neovim.

**Store-backed config:** Home Manager sets `AZITHRO_PACK_LOCK` to a writable
state path. Startup validates/seeds it from the bundled lock only when absent;
later starts and Nix rebuilds preserve interactive updates. After
`:ZPack update`, export the mutable lock into a writable checkout:

```vim
:AzithroLockExport /absolute/path/to/azithro/nvim-pack-lock.json
```

A changed destination requires `:AzithroLockExport!` to authorize replacement.
Review, commit and push the exported lock before updating the flake input.
Neither export nor plugin update writes into the Nix store.

To adopt a newly deployed bundled lock (or a Nix-rolled-back manifest):

1. Stop other Neovim processes sharing this lock; export any updates you want to keep.
2. Run `:AzithroLockRefresh`; a differing lock requires `:AzithroLockRefresh!`.
3. **Restart Neovim immediately**, before any further pack updates: native
   `vim.pack` caches lock contents on first use.
4. Run `:ZPack restore`, confirm the proposed changes, then restart again.

Nix rollback alone does **not** roll back mutable plugin state. Refresh/restore
is deliberate; no startup/activation silently overwrites your changes. Lock
helpers refuse symlink/store targets and protect against ordinary concurrent
changes, but replacing an existing file cannot be atomic compare-and-swap
against an unrelated writer. Do not run multiple updaters at once.

## Validation

Run the offline checks with `bash tests/run.sh`. Add `--smoke` for an isolated
full-plugin install and native Blink Pairs matching check. Tests use disposable
state, not your live plugin installations; smoke may download plugins/binaries.
See [tests/README.md](tests/README.md) and [nix/README.md](nix/README.md) for
scope and Nix evaluation/build commands. The plugin smoke explicitly mocks
parser installation; real parser/LSP/debugger workflows remain cutover gates.

## Notes

- `noice.nvim` was intentionally removed during cleanup; Snacks already handles the current notification/input/picker needs.
- `ts_ls` and `rust_analyzer` remain Mason-installed in standalone mode, but are not enabled directly.
- Go is intentionally minimal for now; add `go.nvim` only if Go-specific commands become worth the extra surface area.

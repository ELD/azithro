# Tests

Run the offline suite from the repository root with `bash tests/run.sh`; add
`--smoke` for full-plugin/native validation. `NVIM` selects the suite runner;
`NVIM_TEST` optionally selects a different binary for the full-plugin child.
Both must provide Neovim 0.13+ and `packlockfile` support.

## Full-plugin smoke test

Run from the repository root with Neovim 0.13+ (the installed executable is the
default):

```sh
nvim --headless -u NONE -i NONE -l tests/smoke.lua
```

To additionally test the pinned Nix executable:

```sh
NVIM_TEST=/nix/store/av2v4vb2hg2p4d2bxwd4r69np0kisaln-neovim-unwrapped-ef3ae3d/bin/nvim \
  nvim --headless -u NONE -i NONE -l tests/smoke.lua
```

To test a separate Neovim 0.13+ binary, set `NVIM_TEST` to its executable path
(for example, an unwrapped build). `NVIM_TEST` must name one executable, not a
command plus arguments. A wrapped build is usable only if it honors the supplied
HOME/XDG environment and does not inject another config or overwrite the smoke
settings. `NVIM_TEST_TIMEOUT_MS` adjusts the child-process timeout; it defaults
to 15 minutes and must be at least 10 seconds. Neovim 0.13+ is required because
the smoke redirects the native `vim.pack` lock with the `packlockfile` option.

The smoke starts a fresh Neovim with the copied Azithro config and real ZPack,
`vim.pack`, and plugin code. It uses `AZITHRO_TOOL_PROVIDER=nix`, disables the
experimental UI for headless mode, fires `UIEnter` and `VeryLazy` manually,
requires Neotest before DAP, checks the configured adapters, TypeScript
preferences, Conform, Markview extras/Blink registration/buffer-local mappings,
and verifies every bundled lock revision in the fresh
native installation. Mason modules must remain unloaded. Both `vim.notify`
ERRORs and `nvim_echo` calls with `err=true` are captured and fail the test.
Blink Pairs must report `library_available() == true`; the smoke then runs its
real Rust parser on a delimiter fixture and asserts the native matching-pair
result. This verifies both the downloaded binary and actual native execution,
not just Lua module loading.

Isolation is mandatory: the child receives a temporary HOME and XDG config,
data, state, cache, config/data search paths, Git global config, TMPDIR, and
working directory. Only `init.lua`, `lua/`, `after/`, and the bundled lock are
copied; `.git` and `target` are excluded. The copied config tree and lock are
chmod read-only. `AZITHRO_PACK_LOCK` points into temporary state, and the test
checks the canonical and copied lock bytes remain unchanged. All child outputs,
including native packages and build products, are confined to the temporary
tree, which is removed after the run unless `AZITHRO_SMOKE_KEEP_TEMP=1` is set.
For Git command tracing, set `AZITHRO_SMOKE_GIT_TRACE=1`; with temp retention,
`git-trace.log` and `git-trace2.json` remain in the temporary root for inspection.

For speed, the test searches existing Neovim plugin checkouts (and optional
roots in the path-list variable `NVIM_TEST_PLUGIN_ROOTS`). A matching checkout
is inspected read-only with lazy Git fetching disabled. When its exact locked
tree is complete, the test copies that revision and any tags directly pointing
at it into a temporary shallow Git mirror, then adds a temporary
`GIT_CONFIG_GLOBAL` `url.*.insteadOf` rewrite. The matching tag refs are needed
for `vim.pack` semver-range resolution; the locked upstream source URL remains
unchanged in the native lock. An absent or incomplete mirror falls back to the
locked upstream source. In either case, installation is a fresh native
`vim.pack` install into temporary XDG data; the user's plugin directories are
never used as install destinations.

The only mock is the `tree-sitter-manager` `setup()` entry point, which prevents
Tree-sitter parser downloads during smoke. ZPack, DAP, Neotest, Conform, Blink,
and completion are not stubbed. Blink's native release download is real; an HTTP
or release-asset failure fails smoke as a blocker rather than being skipped.
Downloads, installed plugins, and build products are confined to the temporary
smoke tree. The Blink shared-library inventory is diagnostic, not a performance
test.

## Git mirror failure investigation

The prior `.git`-only Blink checkout was caused by the smoke's local mirror,
not a bad source URL, inherited `GIT_WORK_TREE`, or an installed `vim.pack`
checkout defect. The child asserts `GIT_DIR` and `GIT_WORK_TREE` are unset. Git
tracing confirmed Git rewrote the HTTPS source to the matching Blink mirror,
while the fresh clone retained the original HTTPS `remote.origin.url`. The
mirror was created with `--no-tags`; Blink's spec uses
a `1.*` version range, so `vim.pack` could not resolve the matching `v1.10.2`
tag and never materialized `lua/blink/cmp/init.lua`. The pinned commit and its
full tree were present in the mirror; the missing tag ref was the fixture gap.

The fixture now mirrors tags pointing directly at the locked revision. The
smoke validates the actual pinned Blink Pairs release asset and native parser
execution on both the default installed Neovim and any selected `NVIM_TEST`
binary. It does not patch `package.path`, manually populate plugin trees, or
bypass ZPack.

## Other focused checks

The other standalone Lua tests can be run from the repository root with:

```sh
nvim --headless -u NONE -i NONE -l tests/runtime.lua
nvim --headless -u NONE -i NONE -l tests/pack.lua
nvim --headless -u NONE -i NONE -l tests/pack-integration.lua
nvim --headless -u NONE -i NONE -l tests/debug.lua
nvim --headless -u NONE -i NONE -l tests/native.lua
nvim --headless -u NONE -i NONE -l tests/markview.lua
```

`tests/native.lua` is an offline stub test for Blink Pairs first-install and
existing-library setup, config-option forwarding, failed-download errors, and
the ZPack build hook. The smoke test above separately downloads and executes the
real platform binary. `tests/envrc.sh` is a shell test and can be run directly.

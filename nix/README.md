# Azithro with Home Manager

Start with [How Azithro fits into nixos-config](HOW-IT-WORKS.md) for a loading
diagram, editable versus store-backed behavior, and everyday update steps.
This page covers the module options and validation details.

`home-manager.nix` is a reusable standalone Home Manager module. Import it into
an existing Home Manager configuration; it does not define a flake, choose a
system, or activate Home Manager. Plugin installation and updates remain with
Azithro/ZPack and Neovim's native `vim.pack`; the module does not declare Home
Manager Neovim plugins. It requires a Home Manager revision that provides
`programs.neovim.sideloadInitLua` (the 26.05 release line or newer) and Neovim
0.13 or newer with the `packlockfile` option. The module asserts this at
evaluation; stable Neovim 0.12.x is rejected before building.

## Import into a system flake

Add Azithro as a non-flake input in the existing system flake:

```nix
# In ~/.nixos-config/flake.nix
azithro = {
  url = "github:ELD/azithro";
  flake = false;
};
```

Import and enable the module in the existing Home Manager configuration:

```nix
{ inputs, ... }:
{
  imports = [ "${inputs.azithro}/nix/home-manager.nix" ];

  programs.azithro = {
    enable = true;
    # Optional; ../. is the module's default source.
    configSource = inputs.azithro;

    # Optional writable checkout instead of the pinned source:
    # editableConfigPath = "/home/alice/src/azithro";
  };
}
```

Use a reviewed Azithro revision in the input URL when one is published. This
module does not edit the surrounding system configuration. For a cutover,
replace the existing Neovim/SigmaVim source wiring and conflicting
`xdg.configFile.nvim` definition; preserve unrelated Home Manager settings and
any separate editable root used by other applications. Import this module once
and do not leave a second manager for the Neovim config link.

`configSource` defaults to the repository root (`../.`). In immutable mode the
module filters it to the runtime subset `init.lua`, `lua/`, `after/`, and
`nvim-pack-lock.json` before placing it in the store, then links that exact
filtered source at `~/.config/nvim` and uses the same path for the sideloaded
`init.lua`. This excludes `.git`, tests, build targets, and other repository
content from the immutable config. Setting `editableConfigPath` instead
creates an out-of-store link to that absolute path and loads its `init.lua`;
`configSource` is then unused.

## Module behavior and options

- Enables `programs.neovim` without overriding its `package` option. The
  existing Home Manager/system package selection is preserved. An assertion
  requires Neovim 0.13+ because Azithro sets `vim.o.packlockfile`. Numeric
  dotted package versions use a normal version comparison; revision-labelled
  derivations are not compared as versions, but checked by parsing
  `NVIM_VERSION_MAJOR` and `NVIM_VERSION_MINOR` from the selected source's
  `CMakeLists.txt`. This accepts a pinned 0.13 nightly whose derivation version
  is a hash without accidentally accepting hashes as release versions. The Nix
  package set is limited to base utilities `curl`, `fd`, `git`, `lazygit`, and
  `ripgrep`; runtimes `nodejs`, `go`, `rustup`, `python3`, and `unzip`; and
  `tree-sitter`, `gnumake`, `pkg-config`, and `stdenv.cc`. It contains no LSPs,
  formatters, linters, debug adapters, or TypeScript. The wrapper selects Mason:
  language servers are ensured automatically, while `:MasonToolsInstall`
  installs other configured tools and `:Mason` manages and updates them. The
  optional `AZITHRO_TOOL_PROVIDER=nix` runtime mode remains available for
  externally provisioned tools, but is not the wrapper default.
- Uses Home Manager's `sideloadInitLua` to load the selected source's
  `init.lua`. Home Manager implements this as an early `--cmd 'lua dofile(...)'`
  wrapper flag. Since the linked config directory also contains `init.lua`,
  that would normally run the file once early and again during normal startup.
  The wrapper therefore uses `-u NONE` to suppress the second load, restores
  `vim.o.loadplugins = true`, and then loads the source exactly once. `-u NONE`
  does not change `stdpath("config")` or the config runtimepath.
- Forces `NVIM_APPNAME=nvim` in the wrapped executable, so Neovim's
  `stdpath("config")` and the Home Manager `~/.config/nvim` link agree. The
  lockfile is under `${config.xdg.stateHome}/nvim`, matching Neovim's state
  directory for this app name. This deliberately overrides an inherited
  `NVIM_APPNAME` (including the repository's `.envrc`) for the managed wrapper;
  an unwrapped development Neovim can use a separate app name.
- Manages only `xdg.configFile.nvim.source`. Immutable mode filters the source
  to `init.lua`, `lua/`, `after/`, and `nvim-pack-lock.json`; the init loader
  and config link share that same filtered path. It does not manage the Neovim
  data directory, plugin state, parser output, or plugin revisions, and does
  not set a global session-wide `NVIM_APPNAME`.
- Exports only `AZITHRO_PACK_LOCK` for the pack lock. Immutable mode points it
  to `${config.xdg.stateHome}/nvim/nvim-pack-lock.json`; editable mode unsets
  that same variable so the checkout's normal lock behavior applies. No legacy
  lock environment aliases are set by the module.
- Exports the UI and profiling switches as `1`/`0`. Experimental UI is enabled
  by default but Lua guards the private API and falls back to Neovim's native
  UI if the API is absent or fails. Profiling is opt-in and defaults off.
- Exposes optional `stitchrPath` as `AZITHRO_STITCHR_PATH`; `null` unsets it.
  The AI options export `AZITHRO_AI_ENABLED` and `AZITHRO_AI_MODEL`; AI is
  disabled by default and an empty model is treated as unset by Lua.
- The migrated wrapper unsets `AZITHRO_JS_DEBUG_COMMAND`,
  `AZITHRO_JS_DEBUG_SERVER`, `AZITHRO_CODELLDB_COMMAND`, and
  `AZITHRO_LIBLLDB_PATH` so inherited adapter overrides do not take precedence
  over Mason-managed debug adapters.

## Integration contract and validation status

The Home Manager wrapper selects Mason: language servers are ensured
automatically, and `:MasonToolsInstall` explicitly installs the other
configured Mason tools. `:Mason` is used to inspect and update them. The Nix
package set is limited to base utilities, runtimes, and parser/build
prerequisites; it contains no LSPs, formatters, linters, debug adapters, or
TypeScript. The optional `AZITHRO_TOOL_PROVIDER=nix` runtime mode is retained
for environments that provision tools externally, but is not the wrapper
default. The wrapper unsets the four JavaScript/CodeLLDB override variables
listed above.

The plugin-lock contract is unchanged: startup reads the single
`AZITHRO_PACK_LOCK` setting before `vim.pack`; immutable and editable lock
behavior remains as described below. Mason-managed tools live in mutable
Neovim state, are not rolled back by Nix, and can be updated without a Home
Manager rebuild. Experimental UI, profiling, AI, and optional Stitchr settings
retain their existing runtime contracts.

The offline test suite passes on unwrapped `v0.13.0-nightly+544d8cd`.
`nixfmt` and Nix parse checks pass, and `nix/check.nix` immutable/editable
evaluations pass for `aarch64-darwin` and `x86_64-linux` using current
system-flake inputs. These checks were read-only; no builds or activation were
performed. Existing build and smoke evidence below is historical, from the
previous Nix-tool-wrapper design; it does not validate real Mason LSP or
adapter workflows. Actual target-platform Mason workflows remain unverified.

## Historical isolated evaluation and build (pre-Mason wrapper)

The repository includes `nix/check.nix`, a standalone Home Manager evaluation
expression. The pinned commands and build results in this section document the
previous Nix-tool-wrapper checks only; they do not verify Mason runtime
workflows. They use the Nixpkgs, Home Manager, and Neovim nightly-overlay
revisions from the reviewed `~/.nixos-config/flake.lock`, and do not evaluate
or edit the system flake. Current read-only Mason-default evaluation results
are summarized above; no package builds or activation were performed.

```sh
NIXPKGS_REV=419fe0f449b3fbe3bdd53d9840288db4509ec32e
HM_REV=7b4c5ec4bedaf1e062bbc1bcaeddbc6bd242aa1b
NVIM_OVERLAY_REV=12716739581f26ef5638213294068a3b4d486e83
CHECK_INPUTS="$(mktemp -d "${TMPDIR:-/tmp}/azithro-nix-check.XXXXXX")"

cat > "$CHECK_INPUTS/flake.nix" <<EOF
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/$NIXPKGS_REV";
    home-manager.url = "github:nix-community/home-manager/$HM_REV";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay/$NVIM_OVERLAY_REV";
    neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = _: { };
}
EOF
(cd "$CHECK_INPUTS" && nix flake lock)

nix-instantiate --parse nix/home-manager.nix >/dev/null
nix-instantiate --parse nix/tools.nix >/dev/null
nix-instantiate --parse nix/check.nix >/dev/null
nixfmt --check nix/home-manager.nix nix/tools.nix nix/check.nix

nix eval --impure --json --expr "
let
  f = builtins.getFlake \"path:$CHECK_INPUTS\";
  check = import ./nix/check.nix {
    nixpkgs = f.inputs.nixpkgs.outPath;
    homeManager = f.inputs.home-manager.outPath;
    overlays = [ f.inputs.neovim-nightly-overlay.overlays.default ];
    system = \"aarch64-darwin\";
  };
in {
  inherit (check) nixpkgsVersion neovimVersion neovimPackageDrvPath finalPackageDrvPath;
  inherit (check) immutable editable;
}"
```

The reviewed pins are Nixpkgs `419fe0f449b3fbe3bdd53d9840288db4509ec32e`,
Home Manager `7b4c5ec4bedaf1e062bbc1bcaeddbc6bd242aa1b`, and nightly overlay
`12716739581f26ef5638213294068a3b4d486e83`. The overlay pins Neovim source
`ef3ae3d19d3f1ab1d3a5f318ad61ac0c707869bb`; its derivation reports version
`ef3ae3d`, while the built executable identifies itself as
`v0.13.0-nightly+ef3ae3d`. The Darwin and Linux Home Manager evaluations
exercised the source-CMake version check for this revision-labelled package.
With no overlay, the default stable `0.12.5` package intentionally fails the
module assertion during evaluation. To evaluate another platform, change the
check's `system` argument; this does not perform a native build.

Build the managed wrapper and selected Neovim package without activating Home
Manager or creating result links. Then exercise the capability on the actual
built Neovim executable:

```sh
FINAL_PACKAGE=$(nix build --impure --no-link --print-out-paths --expr "
let f = builtins.getFlake \"path:$CHECK_INPUTS\";
in (import ./nix/check.nix {
  nixpkgs = f.inputs.nixpkgs.outPath;
  homeManager = f.inputs.home-manager.outPath;
  overlays = [ f.inputs.neovim-nightly-overlay.overlays.default ];
  system = \"aarch64-darwin\";
}).finalPackage")
NVIM_PACKAGE=$(nix build --impure --no-link --print-out-paths --expr "
let f = builtins.getFlake \"path:$CHECK_INPUTS\";
in (import ./nix/check.nix {
  nixpkgs = f.inputs.nixpkgs.outPath;
  homeManager = f.inputs.home-manager.outPath;
  overlays = [ f.inputs.neovim-nightly-overlay.overlays.default ];
  system = \"aarch64-darwin\";
}).neovimPackage")

"$NVIM_PACKAGE/bin/nvim" --headless -u NONE \\
  --cmd 'lua assert(vim.fn.exists("+packlockfile") == 1)' \\
  -c 'lua vim.o.packlockfile = "/tmp/azithro-packlockfile-probe.json"' \\
  -c 'qa!'
```

Historical pre-migration evidence: the aarch64-Darwin `finalPackage` build
succeeded with the pinned nightly, and the packaged Neovim executable passed
the `packlockfile` runtime probe. An isolated wrapper smoke used a disposable
`homeDirectory` and probe `configSource`, manually symlinked the filtered
config, and ran the repository init with only the ZPack bootstrap stubbed. It
confirmed the early sideload ran once and set up the pack lock without loading
the full plugin graph or triggering downloads. Separate builds of
`vscode-js-debug` `1.117.0` and CodeLLDB `1.12.2` succeeded for the old Nix
adapter bundle; these results are historical and are not part of the current
Nix package set. Nothing was activated. Linux was evaluated only; no Linux
runtime/build or Intel macOS verification is claimed. Current Mason-default
checks are evaluations only, not builds or runtime verification.

## Native platform limitations and activation

The historical wrapper build and `packlockfile` probe do not exercise debugger
launches, LSP startup, plugin installation, or third-party tree-sitter parser
compilation. Mason-provided prebuilt binaries may require `nix-ld` or another
compatible dynamic loader on NixOS; this module does not enable or configure
`nix-ld`, and Linux portability is not promised. Local native builds (for
example, a grammar or plugin built at runtime) still depend on a working
compiler toolchain; on macOS the Nix clang wrapper may require an available
Xcode/Command Line Tools SDK. Parser compilation and language-server behavior
must be exercised on each target platform. Native Linux and Intel macOS have
not been verified by the historical build above.

Evaluation and package building are safe checks; do not run `home-manager
switch` as part of them. Activate only through a separately reviewed system
configuration after backing up any conflicting config link and plugin state,
checking rollback, and explicitly authorizing that activation.

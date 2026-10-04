# Azithro with Home Manager

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
  is a hash without accidentally accepting hashes as release versions. Adds
  the `nix/tools.nix` tool set and sets `AZITHRO_TOOL_PROVIDER=nix` in this
  wrapper.
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
- Adds language servers, formatters, linters, parsers/build prerequisites,
  source-control utilities, Node.js, Go, Rustup, and debugger support from
  `nix/tools.nix`. Rustup and project-selected Rust toolchains own `cargo`,
  `rustc`, `rustfmt`, and Clippy; install those components in the selected
  toolchain. The packaged `rust-analyzer` is independent.
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
- Exposes JavaScript and CodeLLDB adapter paths as wrapper variables. In
  particular, CodeLLDB's adapter is not a PATH executable: the module supplies
  its full `.../adapter/codelldb` path as `AZITHRO_CODELLDB_COMMAND`. Debug
  setup (including Rustaceanvim) must use this explicit adapter path, through
  the shared `config.debug.codelldb_adapter` helper, rather than expect
  `codelldb` to resolve from PATH. `vscode-js-debug` is supplied as
  `${pkgs.vscode-js-debug}/bin/js-debug`. The nixpkgs CodeLLDB package supplies
  the adapter's runtime library paths; the module does not set
  `AZITHRO_LIBLLDB_PATH`.

## Current integration readiness

The runtime contract is intended to work end to end: startup reads the single
`AZITHRO_PACK_LOCK` setting before `vim.pack`; Nix mode selects Nix executables
and disables Mason's tool installer/automatic server management; Mason remains
the default outside this wrapper. Experimental UI activation is protected by a
capability check, and `tiny-cmdline` is enabled only after that activation
succeeds. Profiling is controlled by the opt-in environment switch. AI
enable/model values are optional, and the Stitchr grammar is added only when an
explicit local checkout is configured and valid (there is no baked-in host
path). Nix DAP configuration must use the explicit CodeLLDB adapter path
provided above, since that adapter is not exposed as a PATH command.

The reproducible check evaluates immutable and editable modes, forces Home
Manager assertions, checks that the filtered source has only the expected
runtime entries, verifies wrapper contracts, and confirms the module leaves
Home Manager's Neovim package choice unchanged. It accepts optional
`homeDirectory` and `configSource` arguments for isolated wrapper probes; use a
disposable home and manually create the config symlink rather than activating
Home Manager. Evaluation/build are not activation and do not prove every LSP,
debugger, plugin, or locally compiled parser works at runtime. Full native
application-startup and platform-readiness tests remain forthcoming.

## Isolated evaluation and build

The repository includes `nix/check.nix`, a standalone Home Manager evaluation
expression. It accepts explicit Nixpkgs and Home Manager source paths plus
Nixpkgs overlays. The commands below create a temporary isolated flake using
the Nixpkgs, Home Manager, and Neovim nightly-overlay revisions from the
reviewed `~/.nixos-config/flake.lock`; Home Manager and the overlay follow the
same pinned Nixpkgs. They do not evaluate or edit the system flake.

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

The aarch64-Darwin `finalPackage` build succeeded with the pinned nightly, and
the packaged Neovim executable passed the `packlockfile` runtime probe. An
isolated wrapper smoke used a disposable `homeDirectory` and probe
`configSource`, manually symlinked the filtered config beneath that temporary
home, and ran the repository init with only the ZPack bootstrap stubbed. It
confirmed the early sideload looked up `config.runtime` and `config.pack`, ran
once, and set up the pack lock without loading the full plugin graph or
triggering downloads. Separate builds of `vscode-js-debug` `1.117.0`
and CodeLLDB `1.12.2` succeeded. Their configured
`${pkgs.vscode-js-debug}/bin/js-debug` and `.../adapter/codelldb` paths existed,
and both executables' `--help` probes returned successfully without starting
a debug server. Nothing was activated. Linux was evaluated only; no Linux
runtime/build or Intel macOS verification is claimed.

## Native platform limitations and activation

The wrapper build and `packlockfile` smoke test do not exercise debugger
launches, LSP startup, plugin installation, or third-party tree-sitter parser
compilation. Local native builds (for example, a grammar or plugin built at
runtime) still depend on a working compiler toolchain; on macOS the Nix clang
wrapper may require an available Xcode/Command Line Tools SDK. CodeLLDB's host
runtime and Neovim/LLDB compatibility, parser compilation, and language-server
behavior must be exercised on each target platform. Native Linux and Intel
macOS have not been verified by the build above.

Evaluation and package building are safe checks; do not run `home-manager
switch` as part of them. Activate only through a separately reviewed system
configuration after backing up any conflicting config link and plugin state,
checking rollback, and explicitly authorizing that activation.

# Azithro Nix readiness backlog

File-as-a-backlog for replacing SigmaVim in `~/.nixos-config`. Check an item only
when its stated acceptance checks pass. Keep implementation, evaluation, build,
and real workflow validation separate.

**Status:** the Home Manager Mason-default migration is implemented. The
offline suite passes on unwrapped `v0.13.0-nightly+544d8cd`; `nixfmt` and Nix
parse checks pass; and `nix/check.nix` immutable/editable evaluations pass for
`aarch64-darwin` and `x86_64-linux` using current system-flake inputs. These
checks were read-only. No builds or activation were performed. Historical
build evidence from the previous Nix-tool-wrapper design is labeled below.
Actual builds and real Mason workflows remain pending; this is not approval for
activation.

## Decisions and boundaries

- Nix owns Neovim, the Lua configuration, base utilities, runtimes, and
  parser/build prerequisites. `nix/tools.nix` retains `curl`, `fd`, `git`,
  `lazygit`, `ripgrep`; `nodejs`, `go`, `rustup`, `python3`, `unzip`; and
  `tree-sitter`, `gnumake`, `pkg-config`, `stdenv.cc` only.
- Mason owns editor tools under the Home Manager default: it ensures LSPs
  automatically; `:MasonToolsInstall` explicitly installs other tools and
  `:Mason` manages/updates them. The Nix package set has no LSPs, formatters,
  linters, debug adapters, or TypeScript.
- `AZITHRO_TOOL_PROVIDER=nix` remains an optional runtime choice for externally
  provisioned tools; it is not the Home Manager default.
- ZPack/native `vim.pack` owns plugin installations and interactive updates.
- The tracked `nvim-pack-lock.json` is the canonical plugin manifest. Its
  lifecycle is unchanged by the tool-provider migration. Mason tool state is
  mutable, is not rolled back by Nix, and updates do not require an HM rebuild.
- Support editable checkout and immutable store-backed profiles.
- Target Darwin and Linux; Stitchr is optional, with no baked-in host path.
  Mason prebuilt binaries may require `nix-ld` or a compatible loader on NixOS;
  the module does not enable `nix-ld`, and Linux portability is not promised.
- Use `github:ELD/azithro` as a pinned, non-flake input once published.
- ESLint LSP is the sole JS/TS ESLint diagnostics/code-action provider.
- Initial readiness work was Azithro-repository only. The user subsequently
  authorized system-flake wiring ahead of publication, plus an ignored nested
  editable link. No activation, commits, remote changes or publication performed.
- Editable outputs use `~/.nixos-config/checkouts/azithro`, derived from the host
  home directory. This is an independent ignored checkout, not a new submodule.
- Isolated downloads/tests are allowed. Live plugin data is never an install or
  update destination; existing checkouts may be read as sources for temp mirrors.
- Preserve pre-existing working-tree edits, including the lock and Cendre spec.

## 1. Runtime correctness and portability

- [x] **R1 — Correct TypeScript preferences.** Completion/rename preferences now
  live in `tsserver_file_preferences`. Offline and real-plugin smoke check the
  effective values; the upstream README example was misleading.
- [x] **R2 — One ESLint owner.** Removed `eslint_d` from nvim-lint/Mason tools;
  retained ESLint LSP and the existing Conform formatting policy.
- [x] **R3 — Home Manager provider migration.** `lua/config/runtime.lua`
  supports provider, lock path, Stitchr path, UI/profiling flags, and optional AI
  settings. Standalone and Home Manager default to Mason; the wrapper unsets the
  four JavaScript/CodeLLDB override variables. The optional `nix` provider
  remains available for externally provisioned tools only. Offline tests and
  read-only Nix evaluations pass; build and real workflow checks remain pending.
- [x] **R4 — Experimental UI fallback.** Private UI enablement is guarded, with
  native UI fallback and conditional tiny-cmdline. Profiling defaults off.
- [x] **R5 — Optional Stitchr.** Only an explicit absolute path with a readable
  `grammar.js` registers the grammar. Missing checkouts warn without installing.
- [x] **R6 — Safe development environment.** `.envrc` respects XDG_CONFIG_HOME,
  creates parents, and never replaces existing files/directories/symlinks.
- [x] **R7 — Optional AI and cleanup.** AI is opt-in, model configurable, and
  project-local scratch/authentication requirements documented. Removed unused
  Lualine extensions; explained the intentional Snacks `lazy.stats` shim.
- [x] **R8 — Cold-start native artifacts.** Testing found that the initial native
  pack call installs all bundled entries before ZPack registers build hooks.
  Blink Pairs now ensures its native library during setup as well as on builds.
  Failed downloads are not silently swallowed; native delimiter matching passes.
- [x] **R9 — Compatible Neovim requirement.** Stable Neovim 0.12.5 lacks the
  `packlockfile` option. Startup requires 0.13+ and checks the actual capability;
  the Home Manager module rejects unsupported package versions. Revision-labelled
  nightlies are checked via their source CMake version rather than compared as
  hexadecimal release versions. The reviewed system-overlay nightly is compatible.

## 2. Tool ownership

- [x] **T1 — Home Manager Mason mode.** The wrapper selects Mason. LSPs are
  ensured automatically; other tools are installed explicitly with
  `:MasonToolsInstall`, and `:Mason` manages/updates Mason tools. Retain
  `AZITHRO_TOOL_PROVIDER=nix` only as an optional mode for external provisioning.
- [x] **T2 — Mason adapter handoff.** The Home Manager wrapper unsets
  `AZITHRO_JS_DEBUG_COMMAND`, `AZITHRO_JS_DEBUG_SERVER`,
  `AZITHRO_CODELLDB_COMMAND`, and `AZITHRO_LIBLLDB_PATH`. Real Mason-managed
  adapter sessions on target platforms remain a C4 workflow check; historical
  Nix adapter builds do not cover them.
- [x] **T3 — Base Nix package inventory.** `nix/tools.nix` contains only
  `curl`, `fd`, `git`, `lazygit`, `ripgrep`; `nodejs`, `go`, `rustup`,
  `python3`, `unzip`; and `tree-sitter`, `gnumake`, `pkg-config`, `stdenv.cc`.
  It contains no Nix LSPs, formatters, linters, adapters, or TypeScript. Mason
  binaries may require `nix-ld`/a compatible loader on NixOS; the module does
  not enable it, and Linux portability is not promised.

## 3. Plugin lock lifecycle

- [x] **L1 — Early writable lock selection.** Startup sets `packlockfile` before
  the first pack call. Editable mode uses the tracked lock; immutable mode uses
  `AZITHRO_PACK_LOCK` pointing into writable user state. No legacy aliases.
- [x] **L2 — Seed once.** Validates the native manifest and seeds only an absent
  mutable lock. Existing interactive changes survive startup. Invalid locks and
  symlink/store write targets are refused; concurrent creation does not clobber.
- [x] **L3 — Explicit export/refresh.** `:AzithroLockExport[!] {absolute filename}`
  and `:AzithroLockRefresh[!]` protect changed destinations and detect ordinary
  concurrent changes. Refresh warns to restart before restore/update because
  native pack caches lock contents. Commands/refusal paths are tested.
- [x] **L4 — Ownership and rollback documentation.** ZPack delegates persistence
  to native pack. Repositories, logs, caches and parser/query output stay outside
  the immutable config. Nix rollback does not roll back mutable plugins. Stop
  other Neovim processes before replacing a lock: rename cannot provide CAS
  against uncooperative writers after the final snapshot check.

## 4. Repository-local integration and tests

- [x] **I1 — Reusable Home Manager module.** `nix/home-manager.nix` provides
  immutable/editable sources and optional feature settings; reuses the selected
  Neovim package and declares no plugins. Filters immutable config to runtime
  files, excluding the checkout's large build targets and `.git`. Sideloaded
  init executes once, with correct runtimepath and restored plugin loading.
- [x] **I2 — Integration instructions.** `nix/README.md` explains pinned non-flake
  input, replacing SigmaVim wiring, independent editable checkout paths, wrapper
  app-name ownership, evaluation/build and activation boundaries. Root README
  documents runtime settings, lock updates, export, refresh and rollback.
- [x] **V1 — Offline regressions.** `bash tests/run.sh` checks 47 Lua files plus
  runtime settings, TS preferences, ESLint ownership, provider-specific specs,
  debugger/Rust adapter definitions, UI/Stitchr/AI optionality, native hooks,
  `.envrc` safety and lock validation/concurrency guards.
- [x] **V2 — Isolated plugin smoke (historical provider scope).**
  `bash tests/run.sh --smoke` installs locked plugins in fresh data from
  disposable Git mirrors where available, using a read-only config and writable
  state. The smoke remains on the explicit externally provisioned
  `AZITHRO_TOOL_PROVIDER=nix` path; it is not validation of the Home Manager
  Mason-default wrapper. It checks ZPack, lazy events, Neotest-before-DAP,
  Conform, TS preferences, Blink, and unloaded Mason modules. Blink Pairs native
  parsing/matching passes. **Parser installer setup is deliberately mocked; this
  is not C4.**
- [x] **V3 — Mason-default Nix checks.** `nixfmt` and Nix parse checks pass.
  `nix/check.nix` immutable/editable evaluations pass for `aarch64-darwin` and
  `x86_64-linux` using current system-flake inputs, read-only. The offline suite
  passes on unwrapped `v0.13.0-nightly+544d8cd`. No builds or activation were
  performed; actual Mason runtime workflows remain C4.
- [x] **V4 — Native update/restore round trip.** `tests/pack-integration.lua`
  uses a local Git fixture and separate Neovim processes: install pinned commit,
  offline update, export, refresh from read-only bundle, restart and native
  lockfile-target restore. Installed revisions/manifests are asserted; canonical
  locks remain unchanged. No private pack cache mutation or network required.

## 5. External cutover gates — remaining work

- [ ] **C1 — Publish a reviewed revision.** Review/commit intended config/lock
  changes, including the currently untracked Cendre spec and all readiness files;
  publish to `github:ELD/azithro`. The checkout still has no Git remote configured.
  Do not commit unrelated `test-rust` edits implicitly.
- [ ] **C2 — Wire and pin the system flake.** Wiring is implemented: added
  `github:ELD/azithro`, imported/enabled its module, removed old SigmaVim config
  deployment, and assigned the independent editable path. Existing Neovim
  package/aliases/providers and Ghostty root behavior are preserved. The tools
  updater includes Azithro. **Pending after C1:** run `nix flake update azithro`,
  review/commit the resulting lock, and evaluate the actual configurations.
  The stale SigmaVim lock node is intentionally not fabricated/replaced by hand.
- [ ] **C2a — Retire the legacy submodule safely.** Preserve/recover its dirty
  working tree first; then remove the old gitlink/.gitmodules registration in a
  separate change. Review recursive CI checkout and SSH credential requirements.
  No SigmaVim files or registration have been deleted/deinitialized.
- [ ] **C3 — Build actual host outputs.** Evaluate/build the actual editable and
  store-backed Home Manager outputs on Darwin/Linux with their pinned inputs.
  Confirm a compatible nightly, package/option availability, link ownership and
  native binary loaders. The previous Nix-tool-wrapper checks are historical,
  not this gate. Mason prebuilt binaries may need `nix-ld` or another compatible
  loader on NixOS; this module does not enable it, so Linux portability is not
  promised.
- [ ] **C4 — Validate real workflows.** Rust/Go/TS LSP; save formatting; ESLint
  diagnostics/fixes; nearest/file tests; first-use and Rust/Go/JS DAP sessions;
  HTTP requests; Treesitter compilation/highlighting; completion; experimental
  UI and native binaries on each target platform. Verify project-selected Rust
  components and any Xcode/Command Line Tools requirements. No Linux runtime
  verification, interactive UI testing or real debug sessions completed yet.
- [ ] **C5 — Activate with explicit approval.** Back up conflicting links and
  plugin state/lock; stop Neovim; activate the selected output; verify the managed
  wrapper uses `NVIM_APPNAME=nvim`; keep a tested system and plugin-lock rollback.
  Never overwrite mutable locks automatically during activation.

## Evidence and repeatable commands

```sh
bash tests/run.sh
bash tests/run.sh --smoke
NVIM_TEST=/path/to/compatible/neovim/bin/nvim bash tests/run.sh --smoke
nixfmt --check nix/home-manager.nix nix/tools.nix nix/check.nix
# Pinned standalone evaluation/build commands: nix/README.md.
```

- The offline suite passes on unwrapped `v0.13.0-nightly+544d8cd`.
- Current `nix/check.nix` immutable/editable evaluations pass for
  `aarch64-darwin` and `x86_64-linux` using current system-flake inputs; Nix
  formatting and parse checks pass. These checks were read-only; no builds or
  activation were performed.
- `bash tests/run.sh --smoke` remains on the explicit externally provisioned
  `AZITHRO_TOOL_PROVIDER=nix` path and does not validate the Home Manager
  Mason-default wrapper. The previously recorded smoke runs below are historical.
- Historical standalone Nix checks used Nixpkgs
  `419fe0f449b3fbe3bdd53d9840288db4509ec32e`, Home Manager
  `7b4c5ec4bedaf1e062bbc1bcaeddbc6bd242aa1b`, nightly overlay
  `12716739581f26ef5638213294068a3b4d486e83`, with Neovim source
  `ef3ae3d19d3f1ab1d3a5f318ad61ac0c707869bb`. Exact commands are documented.
- Historical initial stable-package build was not a readiness pass: runtime
  probing exposed missing `packlockfile`; the module now rejects that package.
- A smoke-fixture `.git`-only Blink checkout was traced to omitted semver tags in
  temporary mirrors and fixed. Tests preserve source URLs and locked revisions.
- The stronger native check exposed the genuine missed-build-hook cold-start
  issue (R8); availability and actual delimiter matching now prevent false passes.
- Initial readiness tests isolated configs/data/state and did not modify the
  system flake. Subsequent wiring changed `~/.nixos-config/flake.nix`, its shared
  Home Manager module, README, ignore rules and tools-update input list. The
  current system `flake.lock` remains unchanged; no system flake was edited by
  the current read-only checks.
- Created the ignored `~/.nixos-config/checkouts/azithro` symlink to the existing
  workspace only after confirming the destination was absent. Existing workflow
  edits and the dirty SigmaVim checkout were preserved. No activation or canonical
  plugin lock updates were performed.

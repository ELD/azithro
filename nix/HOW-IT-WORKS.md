# How Azithro fits into nixos-config

Your `~/.nixos-config` chooses the Neovim package and imports Azithro's Home
Manager module. That module connects Neovim to the Lua config. Once Neovim
starts, ZPack manages plugins and Mason manages editor tools.

## The loading path

```text
~/.nixos-config/
|
+-- flake.nix + flake.lock
|   |   azithro = github:ELD/azithro (flake = false)
|   |   flake.lock pins the Azithro revision
|   |
|   +-- modules/home-manager/default.nix
|       |   imports inputs.azithro/nix/home-manager.nix
|       |   enables programs.azithro
|       |   sets configSource = inputs.azithro
|       |
|       +-- Azithro: nix/home-manager.nix
|           |
|           +-- nix/tools.nix --> utilities, runtimes, build tools
|           |
|           +-- config link --> ~/.config/nvim
|           |                   (source depends on mode below)
|           |
|           +-- wrapped nvim --> loads the chosen init.lua once
|                               NVIM_APPNAME=nvim
|                               AZITHRO_TOOL_PROVIDER=mason
|                               |
|                               +-- ZPack / vim.pack --> plugins
|                               +-- Mason -----------> editor tools
|
+-- overlays/00-neovim-nightly.nix --> pkgs.neovim
    modules/shared/home-manager.nix selects that package
    Azithro reuses it; it does not choose another Neovim
```

Azithro is a **non-flake input**: Nix fetches a pinned source tree, then your
configuration imports a `.nix` file from it. Azithro does not need its own
`flake.nix`.

Home Manager evaluates these modules together, builds the wrapper and its
packages, then installs the config link when you activate the generation.
Evaluation or building alone does not switch your live configuration.

## Two ways to load the Lua files

```text
Store-backed output (default)          Editable standalone output

Pinned Azithro input                   Pinned Azithro input
        |                                     |
        +--> Home Manager module              +--> Home Manager module
        |                                     |
        +--> filtered runtime files           +--> editableConfigPath
             in /nix/store                         |
                  |                                v
                  |                   ~/.nixos-config/checkouts/azithro
                  |                   (independent checkout or symlink)
                  v                                v
             ~/.config/nvim                   ~/.config/nvim
```

**Store-backed:** Nix keeps only `init.lua`, `lua/`, `after/`, and
`nvim-pack-lock.json` in the deployed config. To change these files, publish
an Azithro commit, update the input pin, then build and activate a new
generation.

**Editable:** the `edattore-editable@aarch64-darwin` and
`edattore-editable@x86_64-linux` Home Manager outputs point the config link at
`~/.nixos-config/checkouts/azithro`. Edit Lua there and restart Neovim; no Nix
rebuild is needed. The checkout must exist before you use this mode. It is
ignored by nixos-config and is not a submodule.

**The Nix module still comes from the pinned input in both modes.** Editing
`nix/home-manager.nix` or `nix/tools.nix` in the editable checkout does not
change the installed wrapper. Publish and update the input, or use an explicit
local input override for testing.

Full NixOS/nix-darwin host outputs use the store-backed defaults unless you
set `programs.azithro.editableConfigPath` for their Home Manager user too.
Ghostty's `local.editableConfigRoot` is separate and does not move Azithro.

## Who manages what?

| Part | Manager | How you change it |
| --- | --- | --- |
| Neovim executable | nixos-config's nightly overlay and package selection | Update the relevant Nix input, build, activate |
| Lua config and bundled plugin lock | Azithro Git repo; Nix deploys the pinned copy | Edit locally, commit/push; update the Azithro input for deployment |
| Wrapper settings and config link | `nix/home-manager.nix` | Change module/options, build, activate |
| Base utilities, runtimes, compiler tools | `nix/tools.nix` | Change packages, build, activate |
| Plugin checkouts and revisions | ZPack and native `vim.pack` | `:ZPack update` / `:ZPack restore` |
| Language servers | Mason | Ensured automatically; inspect/update with `:Mason` |
| Formatters, linters, debug adapters | Mason | Install with `:MasonToolsInstall`; manage with `:Mason` |

Nix supplies tools such as Git, ripgrep, Node, Go, Python, rustup, and the
compiler prerequisites. This module does not supply language servers,
formatters, linters, or debug adapters through Nix.

The wrapper fixes the app name to `nvim`, even if your shell has a different
`NVIM_APPNAME`. Paths below assume the default XDG directories:

| Location | Contents |
| --- | --- |
| `~/.config/nvim` | Config link managed by Home Manager |
| `~/.local/share/nvim` | Mutable plugin checkouts, Mason installations, and other editor data |
| `~/.local/state/nvim/nvim-pack-lock.json` | Writable plugin lock in store-backed mode |
| `<editable checkout>/nvim-pack-lock.json` | Tracked plugin lock used directly in editable mode |

## Everyday changes

### Change the config or Nix module

1. Edit and test in the Azithro repository. Commit and push the intended changes.
2. In `~/.nixos-config`, run `nix flake update azithro`.
3. Review the `flake.lock` diff, build the intended host or Home Manager output,
   then activate it when ready. Commit the reviewed lock change.

The developer-tools updater in `.github/workflows/update.yml` also includes
`azithro`. It updates the source pin, not the plugin manifest. The system
flake's lock currently contains an Azithro pin; the loading path above does
not establish that any particular generation has been activated.

### Update plugins

Run `:ZPack update`, then restart Neovim. In editable mode, review and commit
the checkout's `nvim-pack-lock.json`.

In store-backed mode, updates change the writable state lock. To keep those
changes in Git, export them to a writable Azithro checkout:

```vim
:AzithroLockExport /absolute/path/to/azithro/nvim-pack-lock.json
```

Replacing a different destination requires `:AzithroLockExport!`. Review,
commit, and push the manifest, then update the system flake's Azithro input.

### Update editor tools

Use `:Mason`. These updates do not require a Home Manager rebuild and do not
change either Git-tracked lockfile.

## What a rollback does

A Nix rollback restores the deployed package, wrapper, and store-backed config.
It does **not** restore plugin checkouts, Mason tools, or an editable checkout.
Store-backed startup seeds a missing writable plugin lock from the bundled
manifest, but never overwrites an existing one, including after a rebuild.

To adopt the bundled plugin lock after an update or rollback:

1. Stop other Neovim processes sharing the lock; export changes you want to keep.
2. Run `:AzithroLockRefresh` (`!` is required if the lock differs).
3. Restart Neovim immediately, then run `:ZPack restore` and confirm the changes.
4. Restart again.

Mason tools need separate management through Mason. On NixOS, some Mason
binaries may also need `nix-ld` or another compatible loader; Azithro's module
does not configure that for you.

For module options and evaluation/build details, see [the Nix reference](README.md).
For lock safeguards, see [Plugin Lock Workflow](../README.md#plugin-lock-workflow).

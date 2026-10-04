# Azithro keymap cheatsheet

**Leader = Space.** Below, `SPC` means press Space, then the listed keys.
Keys are case-sensitive: `sD` and `sd` are different mappings.

Unless marked otherwise, mappings use **normal mode**. `V` = visual,
`X` = visual mode (`x` mappings), `O` = operator-pending, `T` = terminal.
Local leader is `\`; no local-leader mappings are configured.

This covers explicit config mappings, the configured Blink completion preset,
and dashboard shortcuts—not all Neovim or plugin defaults.

## Everyday essentials

| Keys | Action |
|---|---|
| `SPC SPC` | Smart file picker |
| `SPC ff` | Find files |
| `SPC ,` / `SPC fb` | Buffers |
| `SPC /` / `SPC sg` | Grep |
| `SPC sw` | Grep word / visual selection (N/X) |
| `SPC e` | File explorer |
| `-` | Open parent directory (Oil) |
| `SPC bd` | Delete buffer |
| `SPC cR` | Rename file |
| `Ctrl-c` | Clear search highlight |
| `Ctrl-/` | Toggle terminal (`Ctrl-_` is an alias) |
| `SPC sk` | Search keymaps |
| `SPC sh` | Help pages |

## Find and search

All keys below follow `SPC`.

| Keys | Action | Keys | Action |
|---|---|---|---|
| `fc` | Config files | `fg` | Git files |
| `fp` | Projects | `fr` | Recent files |
| `sB` | Grep open buffers | `sb` | Buffer lines |
| `:` / `sc` | Command history | `sC` | Commands |
| `s"` | Registers | `s/` | Search history |
| `sa` | Autocmds | `sH` | Highlights |
| `si` | Icons | `sj` | Jumps |
| `sl` | Location list | `sm` | Marks |
| `sM` | Man pages | `sp` | Plugins |
| `sq` | Quickfix list | `sR` | Resume picker |
| `su` | Undo history | `uC` | Colorschemes |
| `ss` | LSP symbols | `sS` | LSP workspace symbols |
| `sd` | Diagnostics | `sD` | Buffer diagnostics |

## Code and LSP

LSP-attached mappings are buffer-local and require an attached server.

| Keys | Action |
|---|---|
| `gd` / `gD` | Definitions / declarations (Snacks picker) |
| `gr` / `gI` / `gy` | References / implementations / type definitions |
| `gai` / `gao` | Incoming / outgoing calls |
| `K` | Hover (LSP-attached) |
| `SPC rn` | Rename symbol (LSP-attached) |
| `SPC ca` | Code action (LSP-attached, N/X) |
| `SPC cf` | Format buffer (LSP-attached, N/X) |
| `[d` / `]d` | Previous / next diagnostic, with float (LSP-attached) |
| `SPC cd` | Line diagnostic (LSP-attached) |
| `SPC cq` | Diagnostics to location list (LSP-attached) |
| `[[` / `]]` | Previous / next reference (N/T) |

### TypeScript

| Keys | Action |
|---|---|
| `SPC co` | Organize imports |
| `SPC cM` | Add missing imports |
| `SPC cu` | Remove unused |
| `SPC cF` | Fix all |
| `SPC cT` | Rename file |

## Git

| Keys | Action |
|---|---|
| `SPC gg` | Lazygit |
| `SPC gb` | Branches |
| `SPC gl` / `SPC gL` | Log / log for current line |
| `SPC gf` | Log for current file |
| `SPC gs` / `SPC gS` | Status / stash |
| `SPC gd` | Diff hunks picker |
| `SPC gB` | Browse Git location (N/V) |
| `SPC gi` / `SPC gI` | Open / all GitHub issues |
| `SPC gp` / `SPC gP` | Open / all GitHub pull requests |

### Hunks

Buffer-local to Gitsigns-attached buffers. In diff mode, `[h` / `]h` fall back
to `[c` / `]c`.

| Keys | Action |
|---|---|
| `[h` / `]h` | Previous / next hunk |
| `SPC ghs` / `SPC ghr` | Stage / reset hunk or selected range (N/V) |
| `SPC ghS` / `SPC ghR` | Stage / reset buffer |
| `SPC ghp` | Preview hunk |
| `SPC ghb` / `SPC ghB` | Blame line / toggle current-line blame |
| `SPC ghd` / `SPC ghD` | Diff against index / previous revision |
| `SPC ghq` | Hunks to quickfix |
| `ih` | Hunk text object / selection (O/X) |

## Debugging and testing

All keys below follow `SPC`.

| Debug | Action | Test | Action |
|---|---|---|---|
| `db` | Toggle breakpoint | `tt` | Run nearest test |
| `dB` | Conditional breakpoint | `tf` | Run current file |
| `dc` | Continue | `td` | Debug nearest test |
| `di` | Step into | `ts` | Toggle summary |
| `do` | Step over | `to` | Open output |
| `dO` | Step out | `tO` | Toggle output panel |
| `dr` | Toggle REPL | `tw` | Toggle watch for current file |
| `dl` | Run last | `tS` | Stop test |
| `dt` | Terminate | | |
| `du` | Toggle DAP UI | | |

## HTTP and WebSocket

HTTP mappings are available in `http` and `rest` buffers. WebSocket mappings
are not filetype-restricted.

| Keys | Action |
|---|---|
| `SPC ar` / `SPC aa` | Run request / all requests |
| `SPC ap` / `SPC an` | Previous / next request |
| `SPC as` | Show stats |
| `SPC at` | Toggle view |
| `SPC ac` | Copy request |
| `SPC aw` / `SPC aW` | Prompt for URL and open websocat / wscat |

## Markdown

Normal-mode, buffer-local mappings for `markdown`, `quarto`, and `rmd`.

| Keys | Action |
|---|---|
| `SPC mp` / `SPC mP` | Toggle current / all previews |
| `SPC ms` | Toggle split preview |
| `SPC mh` | Toggle hybrid mode |
| `SPC me` / `SPC mc` | Edit / create fenced code block |
| `SPC mx` / `SPC mX` | Toggle checkbox / choose state |
| `SPC m[` / `SPC m]` | Decrease / increase heading level |

In the fenced-code-block editor: `Enter` applies changes; `q` closes the float.

## Outline, diagnostics, and TODOs

| Keys | Action |
|---|---|
| `SPC oo` / `SPC of` | Toggle outline / outline float |
| `SPC on` / `SPC op` | Next / previous symbol |
| `SPC xx` / `SPC xX` | Toggle diagnostics / buffer diagnostics |
| `SPC xs` | Toggle symbols |
| `SPC xl` | Toggle LSP definitions/references |
| `SPC xL` / `SPC xQ` | Toggle location / quickfix list |
| `[t` / `]t` | Previous / next TODO comment |
| `SPC st` | TODO Trouble list |
| `SPC sT` | TODO/FIX/FIXME Trouble list |

## UI and scratch buffers

| Keys | Action |
|---|---|
| `SPC .` / `SPC S` | Toggle / select scratch buffer |
| `SPC n` / `SPC un` | Notification history / dismiss notifications |
| `SPC z` / `SPC Z` | Toggle Zen / zoom |
| `SPC N` | Neovim news |

All toggle keys below follow `SPC`.

| Keys | Toggle | Keys | Toggle |
|---|---|---|---|
| `us` | Spelling | `uw` | Wrap |
| `uL` | Relative numbers | `ul` | Line numbers |
| `ud` | Diagnostics | `uc` | Conceal level |
| `uT` | Treesitter | `ub` | Background |
| `uh` | Inlay hints | `ug` | Indent guides |
| `uD` | Dim | | |

## Completion (Blink default preset)

| Keys | Action |
|---|---|
| `Ctrl-Space` | Open menu, or documentation if menu is open |
| `Ctrl-n` / `Down` | Next item |
| `Ctrl-p` / `Up` | Previous item |
| `Ctrl-e` | Hide menu |
| `Ctrl-y` | Accept completion |
| `Ctrl-k` | Toggle signature help |

## AI (when enabled)

| Keys | Action |
|---|---|
| `SPC 9v` | Visual request (V) |
| `SPC 9x` | Cancel requests |
| `SPC 9s` | Search |

## Dashboard only

These are dashboard shortcuts, not global mappings.

| Key | Action | Key | Action |
|---|---|---|---|
| `f` | Find file | `g` | Grep text |
| `r` | Recent files | `p` | Projects |
| `c` | Config files | `s` | Git status |
| `t` | Terminal | `m` | Mason |
| `l` | Plugins | `q` | Quit |

## Leader groups

Which-key labels these prefixes (they are not independent actions):

`a` API · `b` buffer · `c` code · `d` debug · `f` find · `g` Git ·
`gh` hunks · `m` Markdown · `o` outline · `s` search · `t` test ·
`u` UI · `x` diagnostics.

Mappings live in `init.lua`, `lua/config/keymaps.lua`,
`lua/config/autocmds.lua`, and `lua/plugins/`.

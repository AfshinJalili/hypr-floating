# hypr-floating

A Hyprland plugin for floating windows, in two parts:

- **A `floating` workspace layout.** A workspace whose layout is `floating` floats every window natively: new windows open centred with a cascade, and tile again when the workspace stops floating or the plugin unloads.
- **A stacking fix.** A floating window drawn over a full-screen window takes the clicks.

## The floating layout

A workspace with the layout `floating` floats every window it holds.

- A new window opens floating, 64% x 68% of the monitor's work area (at most 1100 x 760), centred, then stepped diagonally in five 24 px steps so windows opened one after another do not sit exactly on each other.
- Windows the layout floated are its **claimed** windows. When the workspace gets another layout, when a window is carried to a workspace that does not float, or when the plugin unloads, exactly those tile again. A window that floats on its own (a window rule, a dialog, your `togglefloating`) is never claimed, so it stays floating.
- Un-floating a window on a floating workspace (`togglefloating`) sticks: it is tiled, unclaimed, with the geometry dwindle gives it, and new windows still float beside it. Floating it again makes it floating and unclaimed.
- A group floats, tiles and floats again as one; every member gets the claim and the tags.
- Full-screen and maximized windows are left as they are and restore their geometry. The stacking fix below applies to them.
- Special workspaces (the scratchpad) keep whatever state a window arrived with.
- Unloading the plugin (also in the middle of a layout change or a window opening) tiles the claimed windows first, so the session lives and nothing stays floated.

It is a tiled algorithm of Hyprland's own layout system, so everything that picks a layout picks it: a workspace rule, `general:layout`, a live `hl.workspace_rule`.

### Use it

```lua
-- one workspace
hl.workspace_rule({ workspace = "2", layout = "floating" })
-- every workspace
hl.config({ general = { layout = "floating" } })
```

```ini
general {
    layout = floating
}
```

The rule can change while Hyprland runs (`hyprctl eval 'hl.workspace_rule({ workspace = "2", layout = "dwindle" })'`): the workspace floats or tiles at once.

### Tags

The layout tags windows, with tags a window rule can match (`o.window({ tag = ... }, ...)` in Omarchy, `tag:` in a rule):

| Tag | On |
|---|---|
| `hypr-floating-workspace` | every window of a floating workspace |
| `hypr-floating-claimed` | the windows the layout floated |
| `omarchy-floating-workspace` | the same as `hypr-floating-workspace`, with `omarchy_tags` on: what Omarchy's titlebars, shadows and opacity follow |
| `omarchy-mode-floated` | the same as `hypr-floating-claimed`, with `omarchy_tags` on: Omarchy's own mark of a window its floating mode floated |

The Omarchy tags are copies. The layout takes them back only from windows it set them on.

## The stacking fix

### The bug

On a workspace whose full-screen or maximized window is itself *floating*, as every window is on [Omarchy](https://omarchy.org)'s floating workspaces, Hyprland draws every floating window over the full-screen one, whatever the stacking order. But it hands out pointer input in stacking order. So a window can be drawn on top while its clicks go to the full-screen window below it:

- Open B, then A. Make A full screen or maximized, and focus B without raising it (a keybind, `hyprctl dispatch focus`). B is drawn over A; clicking B clicks A.
- Raise B over A, then click A. A is raised, B is still drawn over it, and clicking B clicks A.

### What it does

A floating window that is not pinned is drawn over the full-screen window, and takes input over it, **if and only if it is above it in the stacking order.** The plugin keeps that true:

1. After every change of the stacking order or of the full-screen state, it sets which floating windows are allowed over full screen from their place in the stack.
2. A floating window focused below a floating full-screen window is raised. Otherwise rule 1 would hide it, and Hyprland drops the focus of a hidden window.

A tiled full-screen window, a pinned window and a workspace with no full-screen window are left exactly as Hyprland has them. So are clicks on windows that are not full screen: nothing changes unless a floating window is full screen or maximized.

One thing differs from stock Hyprland on purpose: stock hides every window when a floating window enters full screen, even those stacked above it. With the plugin a window already above the full-screen one stays drawn, and clickable, over it. Click or raise the full-screen window and the windows below it hide.

`spec/` holds a TLA+ model of the rule and what TLC checks about it; `test/` drives a real nested Hyprland to check it end to end.

## Install

Needs Hyprland 0.56 or 0.57. A plugin only loads into the Hyprland it was built for: rebuild it after a Hyprland upgrade. All three ways build the commit `hyprpm.toml` pins for your Hyprland: `main` is for 0.57, and the `hyprland-0.56` branch for 0.56.x.

### hyprpm

Needs `hyprpm` and its build dependencies (`cmake`, `git`, `pkg-config`, a C++23 compiler).

```sh
hyprpm update
hyprpm add https://github.com/AfshinJalili/hypr-floating
hyprpm enable hypr-floating
```

### Arch package

`PKGBUILD` builds the plugin for the installed Hyprland and installs it to `/usr/lib/hypr-floating/hypr-floating.so`:

```sh
makepkg -si
```

```lua
hl.plugin.load("/usr/lib/hypr-floating/hypr-floating.so")
```

### Script

`scripts/install.sh` builds the plugin and installs it to `~/.local/lib/hypr-floating/hypr-floating.so`. It removes the old file before copying, since overwriting a loaded library in place can crash Hyprland, and loads nothing into the running session.

```sh
scripts/install.sh              # the commit pinned for the installed Hyprland
scripts/install.sh --worktree   # this checkout, for development
```

Load it from `hyprland.lua`. Declare it on every config pass, or Hyprland unloads it:

```lua
local hypr_floating = os.getenv("HOME") .. "/.local/lib/hypr-floating/hypr-floating.so"
if io.open(hypr_floating, "r") then
  pcall(hl.plugin.load, hypr_floating)
end
```

### Uninstall

```sh
hyprpm disable hypr-floating && hyprpm remove hypr-floating   # hyprpm
sudo pacman -R hypr-floating-git                              # the package
scripts/uninstall.sh                                          # the script
```

Then take the `hl.plugin.load` line out of `hyprland.lua`. The running session keeps the plugin until the next login; `hyprctl plugin unload` tiles the windows the layout floated and keeps the session.

### Manual build

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
ctest --test-dir build        # unit tests; no Hyprland needed
```

This produces `build/hypr-floating.so`. Build against the headers of the Hyprland you run. Without Hyprland's headers, `-DHYPR_FLOATING_PLUGIN=OFF` builds and tests the rules alone.

## Configuration

| Option | Default | Does |
|---|---|---|
| `plugin:hypr_floating:stacking_fix` | `1` | `0` turns the stacking fix off: Hyprland behaves as stock, including the bug |
| `plugin:hypr_floating:omarchy_tags` | `1` | `0` leaves the `omarchy-*` tags out (the `hypr-floating-*` tags stay) |

```lua
hl.config({ plugin = { hypr_floating = { stacking_fix = 1, omarchy_tags = 1 } } })
```

```ini
plugin {
    hypr_floating {
        stacking_fix = 1
        omarchy_tags = 1
    }
}
```

## Omarchy

[Omarchy](https://omarchy.org)'s floating workspaces are a Lua workaround (`default/hypr/workspace-modes.lua`): Hyprland had no layout that floats, so Omarchy floats the windows itself, claims them with the tag `omarchy-mode-floated`, and tags every window of the workspace `omarchy-floating-workspace`, which the titlebars, shadows and opaque windows follow. The `floating` layout does the floating natively, with the same placement, and sets the same tags (`omarchy_tags`).

### Both at once

With Omarchy's floating mode on the same workspace, Omarchy's Lua floats a window as it opens, before the layout sees it, so the layout never claims it: Omarchy wins and the layout stays idle. Nothing breaks, and the layout leaves Omarchy's tags alone. `test/run-omarchy.sh` checks it.

### Omarchy's Lua knows a mode, but not floating, for the workspace

This is every Omarchy that has saved a layout for any workspace. With `omarchy_tags` on, Omarchy's Lua watcher sees `omarchy-mode-floated` on a window of a workspace it does not float, takes the window for a leftover of its own mode and tiles it, and strips `omarchy-floating-workspace`. **The layout then looks broken: its windows open tiled.** Set `omarchy_tags = 0` when Omarchy's Lua is in the way.

### Switching from Omarchy's floating mode to the layout

Omarchy keeps its modes in `~/.local/state/omarchy/workspace-layouts/`. A setup with a default of floating has `default.lua` with `o.workspace_mode({ default = "floating" })` and, say, `1.lua` with workspace 1 as dwindle.

1. Delete the saved default. Without one, Omarchy takes Hyprland's own `general:layout` as the default:

   ```sh
   rm ~/.local/state/omarchy/workspace-layouts/default.lua
   ```

2. In `~/.config/hypr/hyprland.lua`, after `require("default.hypr.toggles")` (which loads Omarchy's saved modes), add the lines of [`examples/omarchy.lua`](examples/omarchy.lua):

   ```lua
   hl.config({ general = { layout = "floating" }, plugin = { hypr_floating = { omarchy_tags = 0 } } })
   o.workspace_mode({ workspace = "99", mode = "floating" })
   hl.config({ plugin = { hyprbars = { workspace_tag = "hypr-floating-workspace" } } })
   o.window({ tag = "hypr-floating-workspace" }, { opacity = "1.0 override 1.0 override", no_shadow = false })
   ```

   The first line makes every workspace float, except those with a saved layout of their own (`1.lua` keeps workspace 1 dwindle). The second gives Omarchy a floating workspace nobody uses, so it still sets up what floating workspaces need (the titlebar plugin, shadows, opaque windows); the last two point the titlebars and the opacity at the layout's workspaces.

Then reload (`hyprctl reload`) or log in again. `test/run-omarchy.sh` runs these lines against Omarchy's own Lua.

What Omarchy's Lua mode does that the layout does not:

- A floating workspace no longer sets `input:follow_mouse = 0`. Add it to your config if you want it.
- Omarchy's cycle (`omarchy-hyprland-workspace-layout-toggle`: dwindle, scrolling, floating) uses Omarchy's Lua floating mode when it reaches floating, not the layout, and saves that mode for the workspace. To give the workspace the layout back, delete its file in `workspace-layouts/` and reload.
- Omarchy's bar and dock read a workspace's layout with `omarchy-hyprland-workspace-layout-current`: it reports `floating` for the layout, from the workspace's `tiledLayout`, and for the default from `general:layout`.

The plugin loads next to the omarchy-macos titlebars and Mission Control plugins (`test/run-floating-plugins.sh`).

## Notes

- Windows in the full-screen window's group are drawn over it by Hyprland whatever their flag; the plugin does not change that.
- Hyprland routes a click to the window the pointer was last over until the pointer moves. A window raised or hidden under a pointer that is perfectly still can take that one click's raise. That is Hyprland's, and a real pointer always moves.
- Switching a workspace to the layout while windows are open floats the tiled ones one tick later, once Hyprland has finished switching.
- The layout's name, `floating`, must be free: loading fails if Hyprland or another plugin already has a layout of that name.
- The Hyprland versions differ only in `src/compat.hpp`.
- `spec/` models the layout's bookkeeping (`Floating.tla`) as well as the stacking rule.

## Layout of the repository

| Path | What |
|---|---|
| `src/stacking.{hpp,cpp}` | The stacking rule, as plain values in and out; no Hyprland |
| `src/stackingFix.{hpp,cpp}` | Applies it: hooks `CWindowState::moveToZ`, listens to window events |
| `src/floating.{hpp,cpp}` | The floating layout's bookkeeping (placement, claims, marks), plain values; no Hyprland |
| `src/layout/` | The layout on Hyprland: `floatingAlgo` (the tiled algorithm), `claims` (claims and tags on windows), `floatingLayout` (install, events) |
| `src/compat.hpp` | The calls that differ between Hyprland versions |
| `src/config.{hpp,cpp}`, `src/main.cpp` | Options and the plugin entry points |
| `test/unit/` | Unit tests (CTest) |
| `test/run-*.sh` | Nested Hyprland tests, see `AGENTS.md` |
| `spec/` | TLA+ models and `check.sh` |
| `examples/omarchy.lua` | The config that switches Omarchy from its floating mode to the layout |
| `PKGBUILD`, `scripts/` | Packaging and the user install |

## License

BSD-3-Clause, see `LICENSE`.

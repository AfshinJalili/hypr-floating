# hypr-floating

A Hyprland plugin for floating windows, in two parts:

- **A `floating` workspace layout.** A workspace whose layout is `floating` floats every window natively: new windows open centred with a cascade. A workspace's layout is the truth for its windows: they all tile when it changes to a tiled layout, all float when it changes back, and a window carried to another workspace takes that one's.
- **A stacking fix.** A floating window drawn over a full-screen window takes the clicks.

## The floating layout

A workspace's layout (its mode) decides whether its windows float: a window floats exactly when its workspace's layout is `floating` or it **floats by its own nature**, that is, Hyprland floated it as it opened (a dialog, a transient or fixed-size window) or a window rule floats it. Those float everywhere and are never tiled by the plugin.

- A new window opens floating, 64% x 68% of the monitor's work area (at most 1100 x 760), centred, then stepped diagonally in five 24 px steps so windows opened one after another do not sit exactly on each other.
- The mode reaches a window when its workspace's layout changes (between any two layouts: dwindle to scrolling tiles a window you floated by hand too), when it opens, when it is carried to another workspace (a dispatcher, a Mission Control drop, another monitor, coming back from Omarchy's minimized windows), and when it leaves full screen or maximized. Every window of the workspace then floats or tiles together, whoever floated or tiled it before: the layout, you, or a script.
- In between, `togglefloating` works on any window: un-floating one on a floating workspace tiles it with the geometry dwindle gives it, and new windows still float beside it. That holds until the mode next reaches the window.
- A group floats and tiles as one; it floats on its own if one of its windows does.
- Full-screen and maximized windows are left as they are while they are, and restore their geometry. The stacking fix below applies to them.
- Pinned windows, and windows on special workspaces (the scratchpad, Omarchy's minimized windows), keep whatever state they have.
- Unloading the plugin (also in the middle of a layout change or a window opening) tiles the windows of floating workspaces first, but those that float on their own, so the session lives and nothing stays floated.

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

### The mark

Every window of a floating workspace carries the tag `hypr-floating-workspace`, which a window rule can match (`o.window({ tag = ... }, ...)` in Omarchy, `tag:` in a rule): titlebars, opacity and shadows can follow it. A window carried away loses it.

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

Then take the `hl.plugin.load` line (and the `omarchy.lua` one) out of `hyprland.lua`. The running session keeps the plugin until the next login; `hyprctl plugin unload` tiles the windows of floating workspaces and keeps the session.

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

```lua
hl.config({ plugin = { hypr_floating = { stacking_fix = 1 } } })
```

```ini
plugin {
    hypr_floating {
        stacking_fix = 1
    }
}
```

## Omarchy

[Omarchy](https://omarchy.org)'s floating workspaces are a Lua workaround (`default/hypr/workspace-modes.lua`): with no layout that floats, Omarchy keeps the tiled layout and floats the windows itself, with tags. Next to the plugin that is two systems deciding the same thing, and they fight. [`lua/omarchy.lua`](lua/omarchy.lua) makes Omarchy's floating mode the plugin's layout instead, and keeps everything of Omarchy's working unchanged:

- It replaces `o.workspace_mode`, which Omarchy's toggle (`omarchy-hyprland-workspace-layout-toggle`, Super + L, the bar's layout button), its default layout (`omarchy-hyprland-workspace-layout-default`) and its saved layouts (`~/.local/state/omarchy/workspace-layouts/`) all go through. `mode = "floating"` gives the workspace the layout `floating`, dwindle and scrolling give it theirs, and `default = "floating"` sets `general:layout` to `floating`. Omarchy's Lua floating mode then never acts on a workspace.
- The toggle still saves the mode in those files, and the bar and the dock read it from there (`omarchy-hyprland-workspace-layout-current`), so they show what the workspace is.
- What a floating workspace looks like is Omarchy's own setup (shadows, opaque windows, its titlebars in the theme's colours, or omarchy-macos's), pointed at the plugin's `hypr-floating-workspace` tag.
- On a floating workspace focus follows clicks (`input:follow_mouse = 0`), and your own setting is back on any other, as in Omarchy's floating mode. To leave `follow_mouse` to your own config, load it with `loadfile(path)({ follow_mouse = false })` instead of `dofile(path)`.
- A window opening on a floating workspace brings a maximized window there back to its size, as in Omarchy's floating mode.
- Minimizing (`omarchy-hyprland-window-minimize`) works as before; a window coming back from the dock takes its workspace's mode then.

### Use it

`scripts/install.sh` and the package put `omarchy.lua` next to `hypr-floating.so`. Load it in `~/.config/hypr/hyprland.lua` after the plugin and **before** `require("default.hypr.toggles")`, which loads the saved layouts:

```lua
local hypr_floating = os.getenv("HOME") .. "/.local/lib/hypr-floating"   -- /usr/lib/hypr-floating for the package
if io.open(hypr_floating .. "/hypr-floating.so", "r") then
  pcall(hl.plugin.load, hypr_floating .. "/hypr-floating.so")
  dofile(hypr_floating .. "/omarchy.lua")
end

-- Toggle config flags dynamically.
require("default.hypr.toggles")
```

The saved layouts stay as they are: a `default.lua` with `o.workspace_mode({ default = "floating" })` makes every workspace float with the layout, a `1.lua` with workspace 1 as dwindle keeps it dwindle. Reload (`hyprctl reload`) or log in again; the first reload tiles what Omarchy's Lua had floated where nothing floats now, and the layout floats the rest.

`test/run-omarchy.sh` runs Omarchy's own Lua and scripts against this in a nested Hyprland: the toggle through dwindle, scrolling and floating, the bar, titlebars, minimizing, moves across monitors, a reload.

Without `lua/omarchy.lua`, Omarchy's floating mode keeps floating windows itself and the plugin's layout is not used; the plugin then only brings windows in line when a layout changes or a window moves, which can fight Omarchy's Lua on a workspace it floats.

The plugin loads next to the omarchy-macos titlebars and Mission Control plugins (`test/run-floating-plugins.sh`).

## Notes

- Windows in the full-screen window's group are drawn over it by Hyprland whatever their flag; the plugin does not change that.
- Hyprland routes a click to the window the pointer was last over until the pointer moves. A window raised or hidden under a pointer that is perfectly still can take that one click's raise. That is Hyprland's, and a real pointer always moves.
- The plugin follows Hyprland's events a tick later, once the change has landed: switching a workspace to the layout floats its tiled windows then, and a window carried in takes the mode then.
- The layout's name, `floating`, must be free: loading fails if Hyprland or another plugin already has a layout of that name.
- The Hyprland versions differ only in `src/compat.hpp`.
- `spec/` models the layout's bookkeeping (`Floating.tla`) as well as the stacking rule.

## Layout of the repository

| Path | What |
|---|---|
| `src/stacking.{hpp,cpp}` | The stacking rule, as plain values in and out; no Hyprland |
| `src/stackingFix.{hpp,cpp}` | Applies it: hooks `CWindowState::moveToZ`, listens to window events |
| `src/floating.{hpp,cpp}` | The floating layout's rule (placement, what the mode asks of a window, the mark), plain values; no Hyprland |
| `src/layout/` | The layout on Hyprland: `floatingAlgo` (the tiled algorithm), `modeSync` (applies the mode and the mark to windows), `floatingLayout` (install, the events and the layout-change hook that tell `modeSync`) |
| `src/compat.hpp` | The calls that differ between Hyprland versions |
| `src/config.{hpp,cpp}`, `src/main.cpp` | Options and the plugin entry points |
| `test/unit/` | Unit tests (CTest) |
| `test/run-*.sh` | Nested Hyprland tests, see `AGENTS.md` |
| `spec/` | TLA+ models and `check.sh` |
| `lua/omarchy.lua` | Omarchy's workspace modes on the layout: loaded from `hyprland.lua` |
| `PKGBUILD`, `scripts/` | Packaging and the user install |

## License

BSD-3-Clause, see `LICENSE`.

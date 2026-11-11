# hypr-floating

A Hyprland plugin for floating windows. Stage 1 is one fix: **a floating window drawn over a full-screen window takes the clicks.**

## The bug

On a workspace whose full-screen or maximized window is itself *floating*, as every window is on [Omarchy](https://omarchy.org)'s floating workspaces, Hyprland draws every floating window over the full-screen one, whatever the stacking order. But it hands out pointer input in stacking order. So a window can be drawn on top while its clicks go to the full-screen window below it:

- Open B, then A. Make A full screen or maximized, and focus B without raising it (a keybind, `hyprctl dispatch focus`). B is drawn over A; clicking B clicks A.
- Raise B over A, then click A. A is raised, B is still drawn over it, and clicking B clicks A.

## What it does

A floating window that is not pinned is drawn over the full-screen window, and takes input over it, **if and only if it is above it in the stacking order.** The plugin keeps that true:

1. After every change of the stacking order or of the full-screen state, it sets which floating windows are allowed over full screen from their place in the stack.
2. A floating window focused below a floating full-screen window is raised. Otherwise rule 1 would hide it, and Hyprland drops the focus of a hidden window.

A tiled full-screen window, a pinned window and a workspace with no full-screen window are left exactly as Hyprland has them. So are clicks on windows that are not full screen: nothing changes unless a floating window is full screen or maximized.

One thing differs from stock Hyprland on purpose: stock hides every window when a floating window enters full screen, even those stacked above it. With the plugin a window already above the full-screen one stays drawn, and clickable, over it. Click or raise the full-screen window and the windows below it hide.

`spec/` holds a TLA+ model of the rule and what TLC checks about it; `test/` drives a real nested Hyprland to check it end to end.

## Install

Needs Hyprland 0.56 or 0.57, `hyprpm` and its build dependencies (`cmake`, `git`, `pkg-config`, a C++23 compiler).

```sh
hyprpm update
hyprpm add https://github.com/AfshinJalili/hypr-floating
hyprpm enable hypr-floating
```

hyprpm builds the plugin for the Hyprland you run. `main` targets Hyprland 0.57; `hyprpm.toml` pins 0.56.x to a commit on the `hyprland-0.56` branch, so 0.56 users build the right sources.

To load it from your config instead of hyprpm, build it (below) and add the path:

```lua
hl.plugin.load("/path/to/hypr-floating.so")
```

### Uninstall

```sh
hyprpm disable hypr-floating
hyprpm remove hypr-floating
```

### Manual build

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
ctest --test-dir build        # unit tests of the rule; no Hyprland needed
```

This produces `build/hypr-floating.so`. A plugin only loads into the Hyprland it was built for, so build against the headers of the Hyprland you run. Without Hyprland's headers, `-DHYPR_FLOATING_PLUGIN=OFF` builds and tests the rule alone.

## Configuration

| Option | Default | Does |
|---|---|---|
| `plugin:hypr_floating:stacking_fix` | `1` | `0` turns the fix off: Hyprland behaves as stock, including the bug |

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

It works alongside Omarchy's Lua floating mode: that mode floats every window of a workspace, which is when the bug shows, and the plugin touches nothing of it. It also loads next to the omarchy-macos titlebars and Mission Control plugins (`test/run-with-plugins.sh` checks that they load and run together).

## Notes

- Windows in the full-screen window's group are drawn over it by Hyprland whatever their flag; the plugin does not change that.
- Hyprland routes a click to the window the pointer was last over until the pointer moves. A window raised or hidden under a pointer that is perfectly still can take that one click's raise. That is Hyprland's, and a real pointer always moves.
- Stage 2 will add a floating layout under `src/layout/`.

## Layout

| Path | What |
|---|---|
| `src/stacking.{hpp,cpp}` | The rule, as plain values in and out; no Hyprland |
| `src/stackingFix.{hpp,cpp}` | Applies it: hooks `CWindowState::moveToZ`, listens to window events |
| `src/compat.hpp` | The calls that differ between Hyprland versions |
| `src/config.{hpp,cpp}`, `src/main.cpp` | Options and the plugin entry points |
| `src/layout/` | Reserved for stage 2 |
| `test/unit/` | Unit tests of the rule (CTest) |
| `test/run-*.sh` | Nested Hyprland tests, see `AGENTS.md` |
| `spec/` | TLA+ model and `check.sh` |

## License

BSD-3-Clause, see `LICENSE`.

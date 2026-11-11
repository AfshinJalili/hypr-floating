# Working on hypr-floating

A Hyprland plugin for floating windows. Read `README.md` first.

## Never disturb the user's session

The user works in the Hyprland session you would test in.

- Test only in a nested Hyprland, started with `tools/nested.sh` (`nested_start`; `test/lib.sh` wraps it). It opens silently on an empty workspace (9), keeps rendering there, and stops on exit. Never start `Hyprland` yourself, never open test windows on the user's workspace, never move their focus, never `hyprctl reload`.
- Never load, unload or hot-reload a plugin into the user's session (`hyprctl plugin load/unload`). A plugin crash ends their session.
- `hyprctl activewindow` must be the same before and after a test run. `test/lib.sh` checks it (`host_guard_start`, `host_guard_end`).
- Test windows are `foot --app-id X sleep 600`, opened inside the nested session only. Never `pkill foot` or match processes by name: the user's terminals look the same.

## Branches

- `main` targets the newest Hyprland (0.57) and carries `hyprpm.toml` with the pins.
- `hyprland-0.56` carries the same sources for Hyprland 0.56. `hyprpm.toml` on `main` pins each 0.56.x commit to a commit here.
- A fix goes on both branches. After committing to `hyprland-0.56`, point the pins in `main`'s `hyprpm.toml` at the new commit.
- The two differ only in the Hyprland API calls (`src/compat.hpp`, and wherever else the compiler complains).
- To compile `main` on a machine running 0.56, install 0.57's headers and point pkg-config at them:

  ```sh
  HYPRBARS_CI_WORK=~/.cache/hypr-floating/work ci/hyprland-headers.sh v0.57.1 ~/.cache/hypr-floating/h057
  PKG_CONFIG_PATH=~/.cache/hypr-floating/h057/lib/pkgconfig:~/.cache/hypr-floating/h057/share/pkgconfig cmake -S . -B build057
  ```

  Such a build compiles only; do not run it on a 0.56 session.

## Tests

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j
ctest --test-dir build                          # unit tests of the rule
test/run-click.sh $PWD/build/hypr-floating.so   # drawn over full screen == takes the click
test/run-click.sh none                          # the same on stock Hyprland: shows the bug
test/run-unload.sh $PWD/build/hypr-floating.so  # unload and reload in a nested session
test/run-with-plugins.sh $PWD/build/hypr-floating.so ~/.local/lib/omarchy-macos/omarchy-macos-titlebars.so ~/.local/lib/omarchy-macos/omarchy-macos-mission-control.so
test/run-floating.sh $PWD/build/hypr-floating.so          # the floating layout: open, switch, toggle, fullscreen, groups, move, unload, monitors, tags
test/run-floating-plugins.sh $PWD/build/hypr-floating.so  # ... with the titlebars and Mission Control plugins
test/run-omarchy.sh $PWD/build/hypr-floating.so           # ... next to Omarchy's own Lua, and examples/omarchy.lua
spec/check.sh                                   # TLC on spec/Stacking.tla and spec/Floating.tla, and the variants that must fail (downloads Java and TLC once)
```

The nested tests print PASS or FAIL per check and exit non-zero on any FAIL. Each scenario starts its own nested Hyprland; logs are in `test/logs/`. They read the screen (`grim`) to see which window is drawn at a point, and click with a virtual pointer (`tools/pointer.c`), then compare.

## Hyprland facts that bit us

- On a floating full-screen window, the renderer draws every window with `m_allowedOverFullscreen` over it; input visits floating windows from the top of the stacking order. See `README.md`.
- Entering full screen clears the flag of every window but the full-screen one; leaving sets all. Focusing a floating window sets its flag without raising it. `CWindowState::moveToZ` sets only the moved window's flag.
- A window hidden behind full screen that is focused loses focus.
- A click raises the window the pointer was last over until the pointer moves; the tests move the pointer first.
- Hyprland removes a plugin's function hooks when it unloads it.
- Omarchy's Lua (`workspace-modes.lua`) tiles any window with `omarchy-mode-floated` on a workspace it does not float and strips `omarchy-floating-workspace` from it: the layout's tags must only be taken back from windows it set them on, and `omarchy_tags = 0` is the way out when Omarchy's Lua is in the way.
- Callbacks that change windows run in `doLater` (`ModeSync::syncLater`), never inside the event that announced the change: a move is still being committed then. `ModeSync::stop` cancels the pending one before unload.
- `-fno-gnu-unique` is load-bearing: without it a same-path unload and load keeps the old image.

# The models

Two TLA+ models, both checked by `spec/check.sh`: `Stacking.tla` (the stacking rule of stage 1) and `Floating.tla` (the floating layout's float/tile bookkeeping, at the end).

## The stacking rule

`Stacking.tla` models one workspace the way Hyprland 0.56's code handles it (the file comments cite the source), and the plugin's two rules on top. TLC checks it exhaustively for three windows (four with `--big`): every window floating, tiled or pinned, every order, every action.

```sh
spec/check.sh         # three windows, about 5 seconds; downloads a JRE and TLC (checked by sha256) on first use
spec/check.sh --big   # also four windows, about half a minute on 16 cores
```

## The model

- A workspace has windows in a stacking order, at most one full-screen or maximized window (`fs`), a focused window, and Hyprland's `m_allowedOverFullscreen` flag per window (`over`).
- **Drawing:** a floating window with the flag is drawn over the full-screen window, in stacking order among those with it (`Renderer.cpp`).
- **Input:** pointer input visits floating windows from the top of the stacking order, skipping those without the flag. The full-screen window has the flag, so it stands at its own place in that order (`ViewHitTester.cpp`). Pinned windows come first.
- **Hyprland's actions:** open, close, toggle full screen, `hl.dsp.focus` (sets the flag, does not raise), a click (focuses and raises), raise and lower. Entering full screen clears every other flag, leaving sets them all, and `moveToZ` sets only the moved window's flag. A focused window Hyprland hides loses focus at once.
- `Variant` selects the plugin: `"stock"` (none), `"rule1"` (the flags follow the stacking order after every change), `"full"` (rule 1, and rule 2: a floating window focused below a floating full-screen window is raised).
- Windows that overlap at one point model a click: `DrawnTop` is what the screen shows there, `ClickTarget` what the click reaches.

Not modelled: windows in the full-screen window's group, `togglefloating` of the full-screen window, several monitors or workspaces, tiled windows opening under a full-screen window, animations.

## What TLC checks

| Property | Meaning |
|---|---|
| `DrawnClickableAbove` | (1) With a floating, unpinned full-screen window, a floating unpinned window is drawn over it iff it takes clicks over it iff it is above it |
| `DrawnImpliesClickable` | The bug alone: a window drawn over the full-screen window takes the clicks there |
| `TopDrawnIsTopClicked` | (1, for all overlapping windows at once) what is on top at a point is what a click there reaches |
| `FocusNeverHidden` | (2) A focus event never leaves focus on a window the full-screen window hides |
| `TiledFullscreenIsStock` | (3) Every step that does not end with a floating full-screen window is a step stock Hyprland takes |

A pinned full-screen window is outside the rule (Hyprland takes input for a pinned window before any other), so it counts as stock.

## Results

`Variant = "full"` (the plugin), three windows:

```
Model checking completed. No error has been found.
275364 states generated, 18233 distinct states found, 0 states left on queue.
```

Four windows:

```
Model checking completed. No error has been found.
12605805 states generated, 566433 distinct states found, 0 states left on queue.
```

Without the plugin's rules TLC finds the original bug (`Stacking_stock.cfg`, invariant `DrawnImpliesClickable`). The counterexample (the `floating` and `pinned` lines are left out: `w2` and `w3` float, nothing is pinned): a floating window `w2` is full screen, a second window `w3` opens above it, then `w2` is raised (a click on it, or `bring_to_top`). `w3` keeps its flag, so it is drawn over `w2`, and the click there reaches `w2`, now above it:

```
State 1: <Initial predicate>
/\ focus = none
/\ order = <<>>
/\ fs = none
/\ dropped = FALSE
/\ over = (w1 :> TRUE @@ w2 :> TRUE @@ w3 :> TRUE)
State 2: <OpenWin line 137, col 5 to line 140, col 92 of module Stacking>
/\ focus = w2
/\ order = <<w2>>
/\ fs = none
/\ dropped = FALSE
/\ over = (w1 :> TRUE @@ w2 :> TRUE @@ w3 :> TRUE)
State 3: <ToggleFullscreen line 153, col 5 to line 157, col 110 of module Stacking>
/\ focus = w2
/\ order = <<w2>>
/\ fs = w2
/\ dropped = FALSE
/\ over = (w1 :> FALSE @@ w2 :> TRUE @@ w3 :> FALSE)
State 4: <OpenWin line 137, col 5 to line 140, col 92 of module Stacking>
/\ focus = w3
/\ order = <<w2, w3>>
/\ fs = w2
/\ dropped = FALSE
/\ over = (w1 :> FALSE @@ w2 :> TRUE @@ w3 :> TRUE)
State 5: <RaiseWin line 182, col 5 to line 184, col 77 of module Stacking>
/\ focus = w3
/\ order = <<w3, w2>>
/\ fs = w2
/\ dropped = FALSE
/\ over = (w1 :> FALSE @@ w2 :> TRUE @@ w3 :> TRUE)
```

`Stacking_stock_top.cfg` finds the same bug for all windows at once. `Stacking_stock_above.cfg` shows the other half of invariant 1 failing in stock: entering full screen hides a window stacked above the full-screen one, which the plugin shows.

With rule 1 but without rule 2 (`Stacking_rule1.cfg`, invariant `FocusNeverHidden`) the click bug is gone and something else breaks: `hl.dsp.focus` on a floating window below a floating full-screen window gives it the flag, rule 1 takes the flag away again, and Hyprland drops the focus of a window it hides.

```
State 1: <Initial predicate>
/\ focus = none
/\ order = <<>>
/\ fs = none
/\ dropped = FALSE
/\ over = (w1 :> TRUE @@ w2 :> TRUE @@ w3 :> TRUE)
State 2: <OpenWin line 137, col 5 to line 140, col 92 of module Stacking>
/\ focus = w2
/\ order = <<w2>>
/\ fs = none
/\ dropped = FALSE
/\ over = (w1 :> TRUE @@ w2 :> TRUE @@ w3 :> TRUE)
State 3: <OpenWin line 137, col 5 to line 140, col 92 of module Stacking>
/\ focus = w3
/\ order = <<w2, w3>>
/\ fs = none
/\ dropped = FALSE
/\ over = (w1 :> TRUE @@ w2 :> TRUE @@ w3 :> TRUE)
State 4: <ToggleFullscreen line 153, col 5 to line 157, col 110 of module Stacking>
/\ focus = w3
/\ order = <<w2, w3>>
/\ fs = w3
/\ dropped = FALSE
/\ over = (w1 :> FALSE @@ w2 :> FALSE @@ w3 :> TRUE)
State 5: <FocusWin line 162, col 5 to line 168, col 64 of module Stacking>
/\ focus = none
/\ order = <<w2, w3>>
/\ fs = w3
/\ dropped = TRUE
/\ over = (w1 :> FALSE @@ w2 :> FALSE @@ w3 :> TRUE)
```

The trace: `w2` and `w3` float, `w3` opens above and goes full screen, then `w2`, below it, is focused. In the last state `focus = none` and `dropped = TRUE`. That is why rule 2 exists.

`TiledFullscreenIsStock` is not vacuous: making the plugin apply rule 1 to a tiled full-screen window as well makes TLC report `Action property TiledFullscreenIsStock is violated`.

## Limits

The model is only as good as its reading of Hyprland, which `test/run-click.sh` checks against the real compositor (drawn and clicked windows match the model's predictions, and stock Hyprland shows the bug). It cannot say anything about code the model does not have, such as the X11 transient stack that `moveToZ` raises with a window.

# The floating layout's bookkeeping

`Floating.tla` models what `src/floating.hpp` decides: which windows a floating workspace floats, and which of them tile again when the workspace stops floating or the plugin unloads. TLC checks it for three windows on two workspaces with one group (about 11 000 distinct states, a second).

```sh
spec/check.sh         # also runs this model, and the variants below
```

## The model

- A workspace has a requested layout, `"floating"` or `"tiled"`, and floats its windows only while the plugin is loaded.
- Per window, `origin` is the ground truth only the model sees: `"tiled"`, `"own"` (it floats on its own: a float rule, a dialog, the user) or `"plugin"` (the layout floated it). `claimed` is the plugin's mark on the window. `explicit` says the user un-floated it and it has stayed tiled.
- Actions: a window opens (alone, floated by a rule, or into an existing group), a window becomes a group, closes, the user toggles floating, a window moves to another workspace, a workspace's layout changes live, the plugin unloads, the plugin loads.
- After any change `Sync` is the one place that floats and tiles: a tiled window the user did not un-float floats on a floating workspace, and a claimed window tiles on one that does not float. A group floats and tiles as one.
- `Variant` switches rules off, to show each one is needed: `"full"` (all on), `"refloat"`, `"noexit"`, `"headtag"`, `"nogroup"`, `"all"`.

Not modelled: special workspaces (a minimized window keeps its state), pinned windows (tiling would unpin them) and full-screen windows (left as they are), several monitors, the order of windows, and the tags Hyprland's events set a tick late.

## What TLC checks

| Property | Meaning |
|---|---|
| `FloatingWorkspaceFloats` | On a floating workspace every window the user did not explicitly tile floats |
| `ExplicitSticks` | A window the user un-floated (togglefloating) there is tiled: the layout does not float it again |
| `NothingFloatedWhereNothingFloats` | After a workspace stops floating or the plugin unloads, no window the layout floated is still floating |
| `UserFloatedStayFloating` | A window that floats on its own stops floating only when the user tiles it |
| `ClaimedExact` | The mark is on exactly the windows the layout floated: never on a tiled window, on every member of a floated group |
| `GroupCoherent` | The members of a group share their floating state and their claim |

## Results

`Variant = "full"`:

```
Model checking completed. No error has been found.
142976 states generated, 10856 distinct states found, 0 states left on queue.
```

Each variant without one rule fails the property that rule is for (the traces are the shortest TLC found; `SHOW_TRACE=1 spec/check.sh` prints them):

| Variant | Fails | Counterexample |
|---|---|---|
| `refloat` | `ExplicitSticks` | A window opens on a floating workspace (the layout floats it); the user toggles it; the layout floats it again, `explicit` set, `origin = "plugin"`. The user's choice is lost: caveat 1 |
| `noexit` | `NothingFloatedWhereNothingFloats` | A window opens on a floating workspace; the plugin unloads. The window floats and nothing floats it: caveat 2 |
| `headtag` | `ClaimedExact` | Two windows form a group while the plugin is unloaded; it loads. Both float, but only the head is claimed: caveat 3 |
| `nogroup` | `ClaimedExact` | A window opens into a claimed floated group, never reaching the layout: it floats unclaimed: caveat 3 |
| `all` | `UserFloatedStayFloating` | A window floats by a rule; it is carried to a workspace that does not float and tiles there, though the user never asked |

## Limits

The model is as good as its reading of the plugin and of Hyprland's float/tile paths; `test/run-floating.sh` checks the same scenarios against the real compositor.

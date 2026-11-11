// The stacking rule, with no Hyprland in it.
//
// On a workspace whose full-screen (or maximized) window floats, Hyprland draws
// every floating window over it, but takes pointer input for floating windows in
// stacking order. A window can then be drawn on top while its clicks go to the
// window below. The rule that fixes it: a floating window is allowed over full
// screen (drawn over it and taking input) exactly when it is above the full-screen
// window in the stacking order.
//
// The functions take a workspace's windows from bottom to top and return plain
// values, so the rule is tested without a compositor (test/unit/).
#pragma once

#include <cstddef>
#include <vector>

namespace HyprFloating::Stacking {

struct SWindow {
    bool floating   = false;
    bool pinned     = false;
    bool fullscreen = false; // the workspace's full-screen or maximized window
};

enum class eVerdict {
    LEAVE, // not ours to decide: the full-screen window itself, pinned and tiled windows
    OVER,  // allowed over full screen
    UNDER, // hidden behind full screen
};

struct SResult {
    bool                  applies = false; // false: the workspace is stock Hyprland's
    std::vector<eVerdict> verdicts;        // one per window, in the order given
};

// Which windows are allowed over full screen. Applies only when the workspace has a
// full-screen window and it floats; a tiled one stays stock Hyprland's.
SResult evaluate(const std::vector<SWindow>& bottomToTop);

// Whether focusing windows[focused] must raise it. A focused floating window below
// a floating full-screen one would be hidden by evaluate(), and Hyprland drops focus
// from a hidden window.
bool needsRaiseOnFocus(const std::vector<SWindow>& bottomToTop, size_t focused);

} // namespace HyprFloating::Stacking

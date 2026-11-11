// The floating layout's rule, with no Hyprland in it.
//
// A workspace's mode is the truth for whether its windows float: a window floats exactly
// when its workspace's layout is "floating" or it floats by its own nature (a float rule,
// a dialog). The plugin applies that when the mode reaches a window: its workspace's layout
// changes, it opens, it moves to another workspace, it leaves full screen. In between the
// user may float or tile a window by hand, until the mode next reaches it.
//
// The functions take plain values and return what the adapter must do, so the rule is
// unit-tested without a compositor (test/unit/) and modelled in spec/Floating.tla.
#pragma once

namespace HyprFloating::Floating {

struct SBox {
    double x = 0, y = 0, w = 0, h = 0;
};

// Where and how big a window the layout floats opens: 64% x 68% of the work area
// (at most 1100 x 760), centred, then stepped diagonally from the centre so windows
// opened one after another do not sit exactly on each other.
constexpr int CASCADE_STEPS = 5;
SBox          openSize(const SBox& workArea);
SBox          openBox(const SBox& workArea, int cascade);
int           nextCascade(int cascade);

enum class eWorkspace {
    FLOATING,
    TILED,   // any other layout
    SPECIAL, // the scratchpad, the minimized windows: they keep whatever state a window arrived with
};

struct SWindow {
    eWorkspace workspace  = eWorkspace::TILED;
    bool       floating   = false;
    bool       ownFloat   = false; // floats by its own nature: a float rule, a dialog (for a group: any member)
    bool       pinned     = false;
    bool       fullscreen = false; // full screen or maximized
};

enum class eAction {
    KEEP,
    FLOAT,
    TILE,
};

// The workspace's mode reaches the window. A window on a special workspace, a pinned one
// (tiling would unpin it) and a full-screen one are left as they are.
eAction applyMode(const SWindow& w);

// How a tiled window reached the layout of a floating workspace.
enum class eArrival {
    ARRIVED, // it opened, was carried here, or the workspace started floating: the mode reaches it
    TOGGLED, // the user un-floated it here (togglefloating): that holds until the mode next reaches it
};

eAction onArrival(eArrival how, const SWindow& w);

// Whether the window carries the layout's mark (every window of a floating workspace has
// it; titlebars and opacity follow it). A special workspace keeps what the window had.
bool marked(eWorkspace workspace, bool wasMarked);

} // namespace HyprFloating::Floating

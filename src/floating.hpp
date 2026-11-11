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

#include <optional>

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
    bool       ownFloat   = false; // floats by its own nature (floatsOnItsOwn; for a group: any member)
    bool       pinned     = false;
    bool       fullscreen = false; // full screen or maximized
};

// What makes a window float by its own nature.
struct SOwnFloat {
    bool                requested  = false;        // Hyprland floated it as it mapped: a dialog, a transient, a fixed size
    std::optional<bool> launchRule = std::nullopt; // a rule given with the command that launched it (exec [float]),
                                                   // which Hyprland drops once the window maps: float or tile
    std::optional<bool> rules      = std::nullopt; // the window rules that match the window now: the last that floats or tiles it
};

// Whether the window floats by its own nature. A window rule counts while it matches the
// window: one that matched as it opened and no longer does (scoped to the workspace it
// opened on, or gone from the config since) does not. A launch rule is read last, as
// Hyprland reads it.
bool floatsOnItsOwn(const SOwnFloat& w);

// What a launch rule said, read as the window opens, from what Hyprland read as it mapped
// (every rule that matched it, the launch rule last) and what the registered rules alone
// say then: what Hyprland read and they do not say came from a launch rule. Otherwise
// nothing is kept, and the registered rules decide from then on.
std::optional<bool> launchRule(std::optional<bool> readAtMap, std::optional<bool> registeredRules);

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

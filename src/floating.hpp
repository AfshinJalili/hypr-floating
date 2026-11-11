// The bookkeeping of the floating layout, with no Hyprland in it.
//
// A workspace with the layout "floating" floats every window it holds. A window the
// layout floated is "claimed": it is the one to tile again when the workspace stops
// floating or the plugin unloads. A window that floated on its own (a float rule, a
// dialog, a user's togglefloating) is never claimed, so it stays floating then.
//
// The functions take plain values and return what the adapter must do, so the rules
// are unit-tested without a compositor (test/unit/) and modelled in spec/Floating.tla.
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

// How a window that is tiled reached the layout of a floating workspace.
enum class eArrival {
    ARRIVED, // a new window, one carried here, or one found tiled when the workspace started floating
    TOGGLED, // the user un-floated it here (togglefloating)
};

enum class eArrivalVerdict {
    CLAIM, // float it and claim it
    TILE,  // leave it tiled, unclaimed: the user asked for that, or it cannot float
};

// A user who un-floats a window on a floating workspace is asking for it to stay
// tiled, so it does. A full-screen window is left as it is.
eArrivalVerdict onArrival(eArrival how, bool fullscreen);

enum class eWorkspace {
    FLOATING,
    TILED,   // any other layout
    SPECIAL, // the scratchpad, the minimized windows: they keep whatever state a window arrived with
};

struct SWindow {
    eWorkspace workspace = eWorkspace::TILED;
    bool       floating  = false;
    bool       pinned    = false;
    bool       claimed   = false;
};

// What the Omarchy compatibility tags say about a window.
struct STags {
    bool onFloatingWorkspace = false; // omarchy-floating-workspace: titlebars and shadows follow it
    bool floatedByLayout     = false; // omarchy-mode-floated: the layout floated it
    bool operator==(const STags&) const = default;
};

struct SSync {
    bool                retile  = false; // tile the window again (it was claimed, and its workspace does not float)
    bool                claimed = false; // the window's claim afterwards
    std::optional<STags> tags;           // none: leave the tags as they are
};

// Brings one window in line with its workspace: a claimed window whose workspace does
// not float is tiled again, except a pinned one (tiling would unpin it), which only
// loses its claim. No window keeps a claim while it is tiled.
SSync sync(const SWindow& w);

} // namespace HyprFloating::Floating

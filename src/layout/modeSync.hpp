// Brings Hyprland's windows in line with their workspace's mode: the decisions are
// src/floating.hpp's; this applies them, and keeps the layout's mark (a tag titlebars and
// opacity follow) on the windows of floating workspaces.
#pragma once

#include "../floating.hpp"

#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>

namespace Layout {
    class CAlgorithm;
    class ITarget;
}

namespace HyprFloating::ModeSync {

// What the mode asks of a tiled window reaching the floating layout of ws.
Floating::eAction onArrival(const PHLWINDOW& w, const PHLWORKSPACE& ws, Floating::eArrival how);

// Float a tiled target where the layout opens a window (a group floats as one).
void floatTarget(const SP<::Layout::CAlgorithm>& algo, const SP<::Layout::ITarget>& target);

// The mode reaches every window of ws: its layout changed.
void layoutChanged(const PHLWORKSPACE& ws);

// The mode reaches w: it opened, moved to another workspace, left full screen, or a window
// of its group closed.
void reached(const PHLWINDOW& w);

// Bring the marks in line, and apply what is pending, once the change that asked for it
// has landed.
void syncLater();

// Before the plugin unloads: cancel what is pending, tile the windows of floating
// workspaces (but those that float by their own nature) and take the marks back.
void stop();

// Whether the workspace's layout is the floating layout.
bool floatingWorkspace(const PHLWORKSPACE& ws);

} // namespace HyprFloating::ModeSync

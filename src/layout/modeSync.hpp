// Which windows the floating layout floated ("claimed"), and what follows from it:
// tiling them again, and the tags. The decisions are src/floating.hpp's; this applies
// them to Hyprland's windows.
//
// A claim is a tag on the window (CLAIM_TAG), so it lives and dies with the window,
// follows it between workspaces and survives a config reload, with or without the
// Omarchy tags.
#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>

namespace Layout {
    class CAlgorithm;
    class ITarget;
}

namespace HyprFloating::ModeSync {

// Float a tiled target and claim every window of it (a group floats as one).
void claim(const SP<::Layout::CAlgorithm>& algo, const SP<::Layout::ITarget>& target);

// The layout is being switched to and cannot float the target yet: claim it at the next sync.
void claimLater(const SP<::Layout::ITarget>& target);

// A window opened. One that joined a group never reached the layout, so it takes the
// group's claim: a group is floated or tiled as one. Its tags are set.
void opened(const PHLWINDOW& w);

// Bring the windows of a target in line with their workspace: a window the user kept
// tiled loses its claim, and the tags follow.
void sync(const SP<::Layout::ITarget>& target);

// Every window against its workspace: tile again what is claimed on a workspace that no
// longer floats, set the tags. Runs once the change that needs it has landed.
void syncLater();

// Before the plugin unloads: cancel what is pending and tile again every claimed window.
void stop();

// Whether the workspace's layout is the floating layout.
bool floatingWorkspace(const PHLWORKSPACE& ws);

} // namespace HyprFloating::ModeSync

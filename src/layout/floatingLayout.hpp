// The floating layout: registers the algorithm and keeps the claims and tags in line
// with the windows' workspaces as they open, move and change layout.
#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

namespace HyprFloating::FloatingLayout {

// Throws if Hyprland refuses to register the layout.
void install(HANDLE handle);

// Tiles again every window the layout floated, so the plugin can unload. Hyprland
// calls this before it unregisters the layout and so before it switches workspaces off it.
void uninstall();

} // namespace HyprFloating::FloatingLayout

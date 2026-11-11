// The floating layout: registers the algorithm, and tells ModeSync when a workspace's mode
// reaches windows (a layout change, a window opening, moving, leaving full screen).
#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

namespace HyprFloating::FloatingLayout {

// Throws if Hyprland refuses to register the layout.
void install(HANDLE handle);

// Tiles the windows of floating workspaces (but those that float on their own), so the plugin can unload. Hyprland
// calls this before it unregisters the layout and so before it switches workspaces off it.
void uninstall();

} // namespace HyprFloating::FloatingLayout

// The tiled algorithm named "floating": a workspace whose layout it is floats every
// window. Windows are floated when they reach it (src/floating.hpp decides which).
#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

namespace HyprFloating::FloatingAlgo {

// Registers the layout "floating". Returns false if Hyprland refuses the name.
bool install(HANDLE handle);

} // namespace HyprFloating::FloatingAlgo

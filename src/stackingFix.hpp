// Applies the stacking rule (stacking.hpp) to Hyprland's windows.
#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

namespace HyprFloating::StackingFix {

// Hooks CWindowState::moveToZ and listens to window events. Throws if it cannot hook.
void install(HANDLE handle);

// Stops acting. The windows keep the flags the rule set: they match their stacking
// order, so nothing needs undoing.
void uninstall();

} // namespace HyprFloating::StackingFix

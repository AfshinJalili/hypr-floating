// plugin:hypr_floating:* options.
#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

namespace HyprFloating::Config {

void registerValues(HANDLE handle);

// plugin:hypr_floating:stacking_fix, default on.
bool stackingFix();

} // namespace HyprFloating::Config

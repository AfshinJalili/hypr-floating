// plugin:hypr_floating:* options.
#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

namespace HyprFloating::Config {

void registerValues(HANDLE handle);

// plugin:hypr_floating:stacking_fix, default on.
bool stackingFix();

// plugin:hypr_floating:omarchy_tags, default on: set the tags Omarchy's titlebars, bar
// and scripts read (omarchy-floating-workspace, omarchy-mode-floated).
bool omarchyTags();

} // namespace HyprFloating::Config

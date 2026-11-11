// Whether a window floats by its own nature, read from Hyprland: such a window floats on
// every workspace, whatever the workspace's mode. The rule is src/floating.hpp's
// (floatsOnItsOwn); this reads its inputs.
#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>

namespace HyprFloating::OwnFloat {

// Hyprland floated it as it mapped (a dialog, a transient, a fixed size), a window rule that
// matches it now floats it, or the rule it was launched with did.
bool floats(const PHLWINDOW& w);

// As the window opens: keep what the rule it was launched with said (exec [float]), which
// Hyprland drops once the window maps.
void opened(const PHLWINDOW& w);

// Before the plugin unloads.
void forget();

} // namespace HyprFloating::OwnFloat

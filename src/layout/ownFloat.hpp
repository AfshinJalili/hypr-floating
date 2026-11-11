// Whether a window floats by its own nature, read from Hyprland: such a window floats on
// every workspace, whatever the workspace's mode (src/floating.hpp).
#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>

namespace HyprFloating::OwnFloat {

// Hyprland floated it as it mapped (a dialog, a transient, a fixed size), or a window rule
// floats it.
bool floats(const PHLWINDOW& w);

} // namespace HyprFloating::OwnFloat

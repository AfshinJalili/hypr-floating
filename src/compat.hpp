// The Hyprland API calls that differ between the versions this repo builds against.
// Only this header changes between the main and hyprland-0.56 branches.
#pragma once

#include <hyprland/src/desktop/view/Window.hpp>

namespace HyprFloating::Compat {

inline bool floating(const PHLWINDOW& w) {
    return w->m_isFloating;
}

inline bool pinned(const PHLWINDOW& w) {
    return w->m_pinned;
}

} // namespace HyprFloating::Compat

// The Hyprland API calls that differ between the versions this repo builds against.
// Only this header changes between the main (0.57) and hyprland-0.56 branches.
#pragma once

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>

namespace HyprFloating::Compat {

inline bool mapped(const PHLWINDOW& w) {
    return w->m_isMapped;
}

inline bool floating(const PHLWINDOW& w) {
    return w->m_isFloating;
}

inline bool pinned(const PHLWINDOW& w) {
    return w->m_pinned;
}

inline bool allowedOverFullscreen(const PHLWINDOW& w) {
    return w->m_allowedOverFullscreen;
}

inline void setAllowedOverFullscreen(const PHLWINDOW& w, bool allowed) {
    w->m_allowedOverFullscreen = allowed;
}

// The fade that hides a window behind full screen: what CWindowState::moveToZ sets.
inline void setFullscreenAlpha(const PHLWINDOW& w, float alpha) {
    *w->alpha(Desktop::View::WINDOW_ALPHA_FULLSCREEN) = alpha;
}

} // namespace HyprFloating::Compat

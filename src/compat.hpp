// The Hyprland API calls that differ between the versions this repo builds against.
// Only this header changes between the main (0.57) and hyprland-0.56 branches.
#pragma once

#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>
#include <hyprland/src/desktop/view/window/WindowFullscreenPolicy.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>

namespace HyprFloating::Compat {

inline bool mapped(const PHLWINDOW& w) {
    return w->mapped();
}

inline bool floating(const PHLWINDOW& w) {
    return w->isFloating();
}

inline bool pinned(const PHLWINDOW& w) {
    return static_cast<bool>(w->m_state & Desktop::View::WINDOW_STATE_PINNED);
}

inline bool allowedOverFullscreen(const PHLWINDOW& w) {
    return w->fullscreenPolicy().allowedOverFullscreen();
}

inline void setAllowedOverFullscreen(const PHLWINDOW& w, bool allowed) {
    w->fullscreenPolicy().setAllowedOverFullscreen(allowed);
}

// The fade that hides a window behind full screen: what CWindowState::moveToZ sets.
inline void setFullscreenAlpha(const PHLWINDOW& w, float alpha) {
    *w->presentation().alpha(Desktop::View::WINDOW_ALPHA_FULLSCREEN) = alpha;
}

} // namespace HyprFloating::Compat

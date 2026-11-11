// The Hyprland API calls that differ between the versions this repo builds against.
// Only this header changes between the main (0.57) and hyprland-0.56 branches.
#pragma once

#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/view/Group.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>

#include <vector>

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

// Floats by its own nature: Hyprland floated it as it mapped (a dialog, a transient, a fixed
// size), or a window rule floats it.
inline bool floatsOnItsOwn(const PHLWINDOW& w) {
    return w->m_requestsFloat || w->m_ruleApplicator->static_.floating.value_or(false);
}

inline bool special(const PHLWORKSPACE& ws) {
    return ws->m_isSpecialWorkspace;
}

inline SP<::Layout::CSpace> space(const PHLWORKSPACE& ws) {
    return ws->m_space;
}

// The windows of w's group, w included; w alone when it is not grouped.
inline std::vector<PHLWINDOW> groupMembers(const PHLWINDOW& w) {
    if (!w->m_group)
        return {w};
    std::vector<PHLWINDOW> members;
    for (const auto& ref : w->m_group->windows()) {
        if (const auto m = ref.lock())
            members.push_back(m);
    }
    return members;
}

// Recompute what a window's tags change: its opacity, shadow, border and decorations.
inline void refreshAfterTagChange(const PHLWINDOW& w) {
    w->updateDecorationValues();
}

// The fade that hides a window behind full screen: what CWindowState::moveToZ sets.
inline void setFullscreenAlpha(const PHLWINDOW& w, float alpha) {
    *w->alpha(Desktop::View::WINDOW_ALPHA_FULLSCREEN) = alpha;
}

} // namespace HyprFloating::Compat

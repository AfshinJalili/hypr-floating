// The Hyprland API calls that differ between the versions this repo builds against.
// Only this header changes between the main (0.57) and hyprland-0.56 branches.
#pragma once

#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/view/Group.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>
#include <hyprland/src/desktop/view/window/WindowFullscreenPolicy.hpp>
#include <hyprland/src/desktop/view/window/WindowGroupMembership.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>

#include <vector>

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

// Hyprland floated it as it mapped: a dialog, a transient, a fixed size.
inline bool requestsFloat(const PHLWINDOW& w) {
    return w->suggestsFloat();
}

inline bool special(const PHLWORKSPACE& ws) {
    return ws->type() == Workspace::eWorkspaceType::SPECIAL;
}

inline SP<::Layout::CSpace> space(const PHLWORKSPACE& ws) {
    return ws->space();
}

// The windows of w's group, w included; w alone when it is not grouped.
inline std::vector<PHLWINDOW> groupMembers(const PHLWINDOW& w) {
    const auto& group = w->grouping().group();
    if (!group)
        return {w};
    std::vector<PHLWINDOW> members;
    for (const auto& ref : group->windows()) {
        if (const auto m = ref.lock())
            members.push_back(m);
    }
    return members;
}

// Recompute what a window's tags change: its opacity, shadow, border and decorations.
inline void refreshAfterTagChange(const PHLWINDOW& w) {
    w->presentation().refreshValues();
}

// The fade that hides a window behind full screen: what CWindowState::moveToZ sets.
inline void setFullscreenAlpha(const PHLWINDOW& w, float alpha) {
    *w->presentation().alpha(Desktop::View::WINDOW_ALPHA_FULLSCREEN) = alpha;
}

} // namespace HyprFloating::Compat

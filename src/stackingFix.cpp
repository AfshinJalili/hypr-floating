#include "stackingFix.hpp"

#include "compat.hpp"
#include "config.hpp"
#include "stacking.hpp"

#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>

#include <algorithm>
#include <set>
#include <stdexcept>
#include <vector>

namespace HyprFloating::StackingFix {

using namespace Stacking;

namespace {

CFunctionHook*                   g_moveToZHook = nullptr;
std::vector<CHyprSignalListener> g_listeners;

struct SWorkspaceWindows {
    std::vector<SWindow>    windows; // bottom to top
    std::vector<PHLWINDOW>  handles; // the same, as Hyprland windows
};

// The mapped windows of a workspace, in stacking order.
SWorkspaceWindows snapshot(const PHLWORKSPACE& ws) {
    const auto FS = Fullscreen::controller()->getFullscreenWindow(ws);

    SWorkspaceWindows out;
    for (const auto& w : Desktop::windowState()->windows()) {
        if (!w || !Compat::mapped(w) || w->m_workspace != ws)
            continue;
        out.windows.push_back({.floating = Compat::floating(w), .pinned = Compat::pinned(w), .fullscreen = w == FS});
        out.handles.push_back(w);
    }
    return out;
}

void setOverFullscreen(const PHLWINDOW& w, bool over) {
    if (Compat::allowedOverFullscreen(w) == over)
        return;
    Compat::setAllowedOverFullscreen(w, over);
    w->updateFullscreenInputState();
    Compat::setFullscreenAlpha(w, w->isBlockedByFullscreen() ? 0.F : 1.F);
    g_pHyprRenderer->damageWindow(w);
}

// Part 1 of the rule: what is drawn over the full-screen window and what takes
// input there is what is above it in the stacking order.
void restack(const PHLWORKSPACE& ws) {
    if (!ws || !Config::stackingFix() || !Fullscreen::controller()->hasFullscreen(ws))
        return;

    const auto SNAP   = snapshot(ws);
    const auto RESULT = evaluate(SNAP.windows);
    if (!RESULT.applies)
        return;

    for (size_t i = 0; i < SNAP.handles.size(); ++i) {
        if (RESULT.verdicts[i] != eVerdict::LEAVE)
            setOverFullscreen(SNAP.handles[i], RESULT.verdicts[i] == eVerdict::OVER);
    }
}

void restackAll() {
    std::set<PHLWORKSPACE> seen;
    for (const auto& w : Desktop::windowState()->windows()) {
        if (w && Compat::mapped(w) && w->m_workspace && seen.insert(w->m_workspace).second)
            restack(w->m_workspace);
    }
}

// Part 2: Hyprland brings a focused floating window over full screen without
// raising it. Hidden by part 1, it would lose focus, so it is raised.
void onFocus(const PHLWINDOW& w) {
    if (!w || !w->m_workspace || !Config::stackingFix() || !Fullscreen::controller()->hasFullscreen(w->m_workspace))
        return;

    const auto SNAP = snapshot(w->m_workspace);
    const auto IT   = std::ranges::find(SNAP.handles, w);
    if (IT != SNAP.handles.end() && needsRaiseOnFocus(SNAP.windows, IT - SNAP.handles.begin()))
        Desktop::windowState()->raise(w); // reaches hkMoveToZ, which restacks
}

using MoveToZFn = void (*)(Desktop::CWindowState*, PHLWINDOW, bool);

void hkMoveToZ(Desktop::CWindowState* self, PHLWINDOW w, bool top) {
    reinterpret_cast<MoveToZFn>(g_moveToZHook->m_original)(self, w, top);
    if (w && w->m_workspace)
        restack(w->m_workspace);
}

CFunctionHook* hookMoveToZ(HANDLE handle) {
    for (const auto& fn : HyprlandAPI::findFunctionsByName(handle, "moveToZ")) {
        if (fn.demangled.contains("CWindowState::moveToZ"))
            return HyprlandAPI::createFunctionHook(handle, fn.address, reinterpret_cast<void*>(&hkMoveToZ));
    }
    return nullptr;
}

} // namespace

void install(HANDLE handle) {
    g_moveToZHook = hookMoveToZ(handle);
    if (!g_moveToZHook || !g_moveToZHook->hook())
        throw std::runtime_error("hypr-floating: could not hook CWindowState::moveToZ");

    auto& window = Event::bus()->m_events.window;
    g_listeners.push_back(window.fullscreen.listen([](PHLWINDOW w) { restack(w->m_workspace); }));
    g_listeners.push_back(window.open.listen([](PHLWINDOW w) { restack(w->m_workspace); }));
    g_listeners.push_back(window.active.listen([](PHLWINDOW w, Desktop::eFocusReason) { onFocus(w); }));
    g_listeners.push_back(Event::bus()->m_events.config.reloaded.listen([] { restackAll(); }));
}

void uninstall() {
    // Hyprland removes the plugin's function hooks itself when it unloads it.
    g_listeners.clear();
    g_moveToZHook = nullptr;
}

} // namespace HyprFloating::StackingFix

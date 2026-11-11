#include "modeSync.hpp"

#include "ownFloat.hpp"
#include "../compat.hpp"

#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/TiledAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/supplementary/WorkspaceAlgoMatcher.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>

#include <algorithm>
#include <ranges>
#include <vector>

namespace HyprFloating::ModeSync {

using namespace Floating;

namespace {

constexpr const char* LAYOUT_NAME = "floating";
constexpr const char* MARK_TAG    = "hypr-floating-workspace"; // the window is on a floating workspace

bool                       g_active  = true;
uint64_t                   g_pending = 0; // the sequence of the one sync that is waiting, or 0
int                        g_cascade = 0;
std::vector<PHLWORKSPACEREF> g_changedWorkspaces;
std::vector<PHLWINDOWREF>    g_reachedWindows;

bool tagged(const PHLWINDOW& w, const char* tag) {
    return w->m_ruleApplicator->m_tagKeeper.isTagged(tag, true);
}

void setTag(const PHLWINDOW& w, const char* tag, bool on) {
    if (tagged(w, tag) == on)
        return;
    if (w->m_ruleApplicator->m_tagKeeper.applyTag(std::string(on ? "+" : "-") + tag)) {
        w->m_ruleApplicator->propertiesChanged(Desktop::Rule::RULE_PROP_TAG);
        Compat::refreshAfterTagChange(w);
    }
}

eWorkspace kindOf(const PHLWORKSPACE& ws, bool unloading) {
    if (Compat::special(ws))
        return eWorkspace::SPECIAL;
    return !unloading && floatingWorkspace(ws) ? eWorkspace::FLOATING : eWorkspace::TILED;
}

SWindow describe(const PHLWINDOW& w, eWorkspace workspace) {
    return {
        .workspace  = workspace,
        .floating   = Compat::floating(w),
        .ownFloat   = std::ranges::any_of(Compat::groupMembers(w), OwnFloat::floats), // a group is one target
        .pinned     = Compat::pinned(w),
        .fullscreen = Fullscreen::controller()->isFullscreen(w),
    };
}

bool usable(const PHLWINDOW& w) {
    return w && Compat::mapped(w) && w->m_workspace && Compat::space(w->m_workspace);
}

// The mode reaches one window; its workspace counts as not floating when unloading.
void apply(const PHLWINDOW& w, bool unloading) {
    if (!usable(w))
        return;
    const auto TARGET = w->layoutTarget();
    if (!TARGET || !TARGET->space() || !TARGET->space()->algorithm())
        return;

    switch (applyMode(describe(w, kindOf(w->m_workspace, unloading)))) {
        case eAction::KEEP: break;
        case eAction::FLOAT: floatTarget(TARGET->space()->algorithm(), TARGET); break;
        case eAction::TILE: g_layoutManager->changeFloatingMode(TARGET); break;
    }
}

void mark(const PHLWINDOW& w, bool unloading) {
    if (usable(w))
        setTag(w, MARK_TAG, marked(kindOf(w->m_workspace, unloading), tagged(w, MARK_TAG)));
}

template <typename T>
bool contains(const std::vector<T>& refs, const auto& p) {
    return std::ranges::any_of(refs, [&](const T& ref) { return ref.lock() == p; });
}

void flush() {
    g_pending = 0;

    const auto WORKSPACES = std::move(g_changedWorkspaces);
    const auto REACHED    = std::move(g_reachedWindows);
    g_changedWorkspaces.clear();
    g_reachedWindows.clear();

    const auto WINDOWS = Desktop::windowState()->windows(); // a copy: floating or tiling a window reorders the list
    for (const auto& w : WINDOWS) {
        if (w && (contains(REACHED, w) || contains(WORKSPACES, w->m_workspace)))
            apply(w, false);
    }
    for (const auto& w : WINDOWS) {
        if (w)
            mark(w, false);
    }
}

} // namespace

bool floatingWorkspace(const PHLWORKSPACE& ws) {
    const auto SPACE = ws ? Compat::space(ws) : nullptr;
    if (!SPACE || !SPACE->algorithm() || !SPACE->algorithm()->tiledAlgo())
        return false;
    return ::Layout::Supplementary::algoMatcher()->getNameForTiledAlgo(SPACE->algorithm()->tiledAlgo().get()) == LAYOUT_NAME;
}

eAction onArrival(const PHLWINDOW& w, const PHLWORKSPACE& ws, eArrival how) {
    return Floating::onArrival(how, describe(w, kindOf(ws, !g_active))); // unloading: stop() is tiling it
}

void floatTarget(const SP<::Layout::CAlgorithm>& algo, const SP<::Layout::ITarget>& target) {
    algo->setFloating(target, true, true);

    g_cascade       = nextCascade(g_cascade);
    const auto& WA  = algo->space()->workArea(true);
    const auto  BOX = openBox({WA.x, WA.y, WA.w, WA.h}, g_cascade);
    algo->setTargetGeom(CBox{BOX.x, BOX.y, BOX.w, BOX.h}, target);
}

void layoutChanged(const PHLWORKSPACE& ws) {
    if (!g_active || !ws)
        return;
    g_changedWorkspaces.emplace_back(ws);
    syncLater();
}

void reached(const PHLWINDOW& w) {
    if (!g_active || !w)
        return;
    g_reachedWindows.emplace_back(w);
    syncLater();
}

void syncLater() {
    if (g_active && !g_pending)
        g_pending = g_pEventLoopManager->doLater(flush);
}

void stop() {
    g_active = false;
    if (g_pending)
        g_pEventLoopManager->removeDoLater(g_pending);
    g_pending = 0;
    g_changedWorkspaces.clear();
    g_reachedWindows.clear();

    const auto WINDOWS = Desktop::windowState()->windows();
    for (const auto& w : WINDOWS) {
        if (w && floatingWorkspace(w->m_workspace))
            apply(w, true);
    }
    for (const auto& w : WINDOWS) {
        if (w)
            mark(w, true);
    }
}

} // namespace HyprFloating::ModeSync

#include "claims.hpp"

#include "../compat.hpp"
#include "../config.hpp"
#include "../floating.hpp"

#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/TiledAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/supplementary/WorkspaceAlgoMatcher.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>

#include <algorithm>
#include <vector>

namespace HyprFloating::Claims {

using namespace Floating;

namespace {

constexpr const char* LAYOUT_NAME   = "floating";
constexpr const char* CLAIM_TAG     = "hypr-floating-claimed";
constexpr const char* WORKSPACE_TAG = "omarchy-floating-workspace";
constexpr const char* FLOATED_TAG   = "omarchy-mode-floated";

bool                           g_active  = true;
uint64_t                       g_pending = 0; // the sequence of the one sync that is waiting, or 0
int                            g_cascade = 0;
std::vector<WP<::Layout::ITarget>> g_claimLater;

bool tagged(const PHLWINDOW& w, const char* tag) {
    return w->m_ruleApplicator->m_tagKeeper.isTagged(tag, true);
}

void setTag(const PHLWINDOW& w, const char* tag, bool on) {
    if (tagged(w, tag) == on)
        return;
    if (w->m_ruleApplicator->m_tagKeeper.applyTag(std::string(on ? "+" : "-") + tag)) {
        w->m_ruleApplicator->propertiesChanged(Desktop::Rule::RULE_PROP_TAG);
        w->updateDecorationValues();
    }
}

std::vector<PHLWINDOW> windowsOf(const SP<::Layout::ITarget>& target) {
    const auto W = target->window();
    return W ? Compat::groupMembers(W) : std::vector<PHLWINDOW>{};
}

eWorkspace kindOf(const PHLWORKSPACE& ws, bool unloading) {
    if (Compat::special(ws))
        return eWorkspace::SPECIAL;
    return !unloading && floatingWorkspace(ws) ? eWorkspace::FLOATING : eWorkspace::TILED;
}

// One window against its workspace; the workspace counts as not floating when unloading.
void syncWindow(const PHLWINDOW& w, bool unloading) {
    if (!Compat::mapped(w) || !w->m_workspace || !w->m_workspace->m_space)
        return;

    const auto R = Floating::sync({.workspace = kindOf(w->m_workspace, unloading), .floating = Compat::floating(w), .pinned = Compat::pinned(w), .claimed = tagged(w, CLAIM_TAG)});

    setTag(w, CLAIM_TAG, R.claimed);
    if (R.retile && w->layoutTarget() && w->layoutTarget()->space())
        g_layoutManager->changeFloatingMode(w->layoutTarget());
    if (R.tags && Config::omarchyTags()) {
        setTag(w, WORKSPACE_TAG, R.tags->onFloatingWorkspace);
        setTag(w, FLOATED_TAG, R.tags->floatedByLayout);
    }
}

void syncAll(bool unloading) {
    const auto WINDOWS = Desktop::windowState()->windows(); // a copy: tiling a window reorders the list
    for (const auto& w : WINDOWS) {
        if (w)
            syncWindow(w, unloading);
    }
}

void flush() {
    g_pending = 0;

    auto later = std::move(g_claimLater);
    g_claimLater.clear();
    for (const auto& ref : later) {
        const auto T = ref.lock();
        if (T && !T->floating() && T->space() && T->space()->algorithm() && floatingWorkspace(T->workspace()))
            claim(T->space()->algorithm(), T);
    }

    syncAll(false);
}

} // namespace

bool floatingWorkspace(const PHLWORKSPACE& ws) {
    if (!ws || !ws->m_space || !ws->m_space->algorithm() || !ws->m_space->algorithm()->tiledAlgo())
        return false;
    return ::Layout::Supplementary::algoMatcher()->getNameForTiledAlgo(ws->m_space->algorithm()->tiledAlgo().get()) == LAYOUT_NAME;
}

void claim(const SP<::Layout::CAlgorithm>& algo, const SP<::Layout::ITarget>& target) {
    const auto MEMBERS = windowsOf(target);
    for (const auto& w : MEMBERS)
        setTag(w, CLAIM_TAG, true);

    algo->setFloating(target, true, true);

    g_cascade        = nextCascade(g_cascade);
    const auto& WA   = algo->space()->workArea(true);
    const auto  BOX  = openBox({WA.x, WA.y, WA.w, WA.h}, g_cascade);
    algo->setTargetGeom(CBox{BOX.x, BOX.y, BOX.w, BOX.h}, target);

    for (const auto& w : MEMBERS)
        syncWindow(w, false);
}

void claimLater(const SP<::Layout::ITarget>& target) {
    if (!g_active)
        return;
    g_claimLater.emplace_back(target);
    syncLater();
}

void opened(const PHLWINDOW& w) {
    const auto MEMBERS = Compat::groupMembers(w);
    if (std::ranges::any_of(MEMBERS, [](const PHLWINDOW& m) { return tagged(m, CLAIM_TAG); })) {
        for (const auto& m : MEMBERS)
            setTag(m, CLAIM_TAG, true);
    }
    for (const auto& m : MEMBERS)
        syncWindow(m, false);
}

void sync(const SP<::Layout::ITarget>& target) {
    for (const auto& w : windowsOf(target))
        syncWindow(w, false);
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
    g_claimLater.clear();
    syncAll(true);
}

} // namespace HyprFloating::Claims

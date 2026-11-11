#include "ownFloat.hpp"

#include "../compat.hpp"
#include "../floating.hpp"

#include <hyprland/src/desktop/rule/Engine.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRule.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>

#include <utility>
#include <vector>

namespace HyprFloating::OwnFloat {

namespace {

std::vector<std::pair<PHLWINDOWREF, bool>> g_launchRules; // what a launch rule said, per window it said something of

// What the window rules registered now say of floating the window: the last that matches it
// and floats or tiles it, as Hyprland reads them when a window maps. Hyprland keeps what it
// read then (static_.floating) for the window's life, even once the rule no longer matches it.
std::optional<bool> registeredRules(const PHLWINDOW& w) {
    using namespace Desktop::Rule;
    std::optional<bool> says;
    for (const auto& r : ruleEngine()->rules()) {
        if (r->type() != RULE_TYPE_WINDOW || r->isExecRule())
            continue;
        const auto RULE = reinterpretPointerCast<CWindowRule>(r);
        if (!RULE->matches(w))
            continue;
        for (const auto& effect : RULE->effects()) {
            const auto VALUE = std::get_if<bool>(&effect.value);
            if (!VALUE)
                continue;
            if (effect.key == WINDOW_RULE_EFFECT_FLOAT)
                says = *VALUE;
            else if (effect.key == WINDOW_RULE_EFFECT_TILE)
                says = !*VALUE;
        }
    }
    return says;
}

std::optional<bool> launchRuleOf(const PHLWINDOW& w) {
    for (const auto& [ref, said] : g_launchRules) {
        if (ref.lock() == w)
            return said;
    }
    return std::nullopt;
}

} // namespace

bool floats(const PHLWINDOW& w) {
    return Floating::floatsOnItsOwn({
        .requested  = Compat::requestsFloat(w),
        .launchRule = launchRuleOf(w),
        .rules      = registeredRules(w),
    });
}

void opened(const PHLWINDOW& w) {
    std::erase_if(g_launchRules, [](const auto& entry) { return entry.first.expired(); });
    if (const auto SAID = Floating::launchRule(w->m_ruleApplicator->static_.floating, registeredRules(w)))
        g_launchRules.emplace_back(w, *SAID);
}

void forget() {
    g_launchRules.clear();
}

} // namespace HyprFloating::OwnFloat

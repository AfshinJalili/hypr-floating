#include "ownFloat.hpp"

#include "../compat.hpp"

#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>

namespace HyprFloating::OwnFloat {

bool floats(const PHLWINDOW& w) {
    return Compat::requestsFloat(w) || w->m_ruleApplicator->static_.floating.value_or(false);
}

} // namespace HyprFloating::OwnFloat

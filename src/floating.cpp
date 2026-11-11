#include "floating.hpp"

#include <algorithm>
#include <cmath>

namespace HyprFloating::Floating {

SBox openSize(const SBox& workArea) {
    return {.w = std::min(1100.0, std::floor(workArea.w * 0.64)), .h = std::min(760.0, std::floor(workArea.h * 0.68))};
}

SBox openBox(const SBox& workArea, int cascade) {
    auto       box  = openSize(workArea);
    const auto STEP = cascade * 24.0 - 48.0;
    box.x           = workArea.x + workArea.w / 2 - box.w / 2 + STEP;
    box.y           = workArea.y + workArea.h / 2 - box.h / 2 + STEP;
    return box;
}

int nextCascade(int cascade) {
    return (cascade + 1) % CASCADE_STEPS;
}

eAction applyMode(const SWindow& w) {
    if (w.workspace == eWorkspace::SPECIAL || w.pinned || w.fullscreen)
        return eAction::KEEP;
    const bool WANTS = w.ownFloat || w.workspace == eWorkspace::FLOATING;
    if (WANTS == w.floating)
        return eAction::KEEP;
    return WANTS ? eAction::FLOAT : eAction::TILE;
}

eAction onArrival(eArrival how, const SWindow& w) {
    return how == eArrival::TOGGLED ? eAction::KEEP : applyMode(w);
}

bool marked(eWorkspace workspace, bool wasMarked) {
    return workspace == eWorkspace::FLOATING || (workspace == eWorkspace::SPECIAL && wasMarked);
}

} // namespace HyprFloating::Floating

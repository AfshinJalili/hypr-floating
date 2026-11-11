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

eArrivalVerdict onArrival(eArrival how, bool fullscreen) {
    return how == eArrival::TOGGLED || fullscreen ? eArrivalVerdict::TILE : eArrivalVerdict::CLAIM;
}

SSync sync(const SWindow& w) {
    switch (w.workspace) {
        case eWorkspace::SPECIAL: return {.retile = false, .claimed = w.claimed, .marked = w.marked};
        case eWorkspace::FLOATING: return {.claimed = w.claimed && w.floating, .marked = true};
        case eWorkspace::TILED: break;
    }
    return {.retile = w.claimed && w.floating && !w.pinned};
}

} // namespace HyprFloating::Floating

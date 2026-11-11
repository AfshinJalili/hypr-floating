#include "stacking.hpp"

#include <algorithm>

namespace HyprFloating::Stacking {

static std::vector<SWindow>::const_iterator floatingFullscreen(const std::vector<SWindow>& windows) {
    const auto it = std::ranges::find_if(windows, [](const SWindow& w) { return w.fullscreen; });
    return it != windows.end() && it->floating ? it : windows.end();
}

SResult evaluate(const std::vector<SWindow>& windows) {
    const auto FS = floatingFullscreen(windows);
    if (FS == windows.end())
        return {};

    SResult result{.applies = true, .verdicts = std::vector(windows.size(), eVerdict::LEAVE)};
    for (size_t i = 0; i < windows.size(); ++i) {
        const auto& w = windows[i];
        if (w.fullscreen || w.pinned || !w.floating)
            continue;
        result.verdicts[i] = windows.begin() + i > FS ? eVerdict::OVER : eVerdict::UNDER;
    }
    return result;
}

bool needsRaiseOnFocus(const std::vector<SWindow>& windows, size_t focused) {
    if (focused >= windows.size())
        return false;
    const auto RESULT = evaluate(windows);
    return RESULT.applies && RESULT.verdicts[focused] == eVerdict::UNDER;
}

} // namespace HyprFloating::Stacking

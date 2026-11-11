#include "config.hpp"

#include <hyprland/src/config/ConfigManager.hpp>
#include <hyprland/src/config/values/types/IntValue.hpp>

namespace HyprFloating::Config {

// Kept so stackingFix() reads the resolved value() (a Lua config's too).
static SP<::Config::Values::CIntValue> g_stackingFix;

void registerValues(HANDLE handle) {
    g_stackingFix = makeShared<::Config::Values::CIntValue>("plugin:hypr_floating:stacking_fix", "", ::Config::INTEGER{1});
    HyprlandAPI::addConfigValueV2(handle, g_stackingFix);
}

bool stackingFix() {
    return !g_stackingFix || g_stackingFix->value() != 0;
}

} // namespace HyprFloating::Config

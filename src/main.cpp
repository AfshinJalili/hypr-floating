// hypr-floating: fixes for floating windows in Hyprland. Entry points only.
#include "config.hpp"
#include "stackingFix.hpp"

#include <hyprland/src/plugins/PluginAPI.hpp>

#include <stdexcept>

inline HANDLE PHANDLE = nullptr;

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    HyprFloating::Config::registerValues(handle);
    HyprFloating::StackingFix::install(handle);

    return {"hypr-floating", "Fixes for floating windows: a window drawn over a full-screen one takes the clicks", "Afshin Jalili", "0.1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    HyprFloating::StackingFix::uninstall();
}

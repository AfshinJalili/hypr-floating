// hypr-floating: fixes for floating windows in Hyprland. Entry points only.
#include "config.hpp"
#include "layout/floatingLayout.hpp"
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
    HyprFloating::FloatingLayout::install(handle);

    return {"hypr-floating", "Floating windows: a floating workspace layout, and a window drawn over a full-screen one takes the clicks", "Afshin Jalili", "0.1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    // First: it tiles again what it floated, while the layout is still registered.
    HyprFloating::FloatingLayout::uninstall();
    HyprFloating::StackingFix::uninstall();
}

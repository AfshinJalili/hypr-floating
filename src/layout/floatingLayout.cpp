#include "floatingLayout.hpp"

#include "modeSync.hpp"
#include "floatingAlgo.hpp"

#include <hyprland/src/event/EventBus.hpp>

#include <stdexcept>
#include <vector>

namespace HyprFloating::FloatingLayout {

namespace {

std::vector<CHyprSignalListener> g_listeners;

} // namespace

void install(HANDLE handle) {
    if (!FloatingAlgo::install(handle))
        throw std::runtime_error("hypr-floating: Hyprland has a layout named floating already");

    auto& window = Event::bus()->m_events.window;
    g_listeners.push_back(window.open.listen([](PHLWINDOW w) { ModeSync::opened(w); }));
    // A move is still being committed when this fires; changing the window underneath it loses the move.
    g_listeners.push_back(window.moveToWorkspace.listen([](PHLWINDOW, PHLWORKSPACE) { ModeSync::syncLater(); }));
    g_listeners.push_back(Event::bus()->m_events.config.reloaded.listen([] { ModeSync::syncLater(); }));
}

void uninstall() {
    g_listeners.clear();
    ModeSync::stop();
}

} // namespace HyprFloating::FloatingLayout

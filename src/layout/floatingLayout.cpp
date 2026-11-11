#include "floatingLayout.hpp"

#include "floatingAlgo.hpp"
#include "modeSync.hpp"
#include "ownFloat.hpp"
#include "../compat.hpp"

#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/TiledAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>

#include <stdexcept>
#include <vector>

namespace HyprFloating::FloatingLayout {

namespace {

CFunctionHook*                   g_updateTiledAlgoHook = nullptr;
std::vector<CHyprSignalListener> g_listeners;

using UpdateTiledAlgoFn = void (*)(::Layout::CAlgorithm*, UP<::Layout::ITiledAlgorithm>&&);

// Every change of a workspace's layout passes here, whichever two layouts it is between
// (dwindle -> scrolling too): the mode reaches every window of the workspace.
void hkUpdateTiledAlgo(::Layout::CAlgorithm* self, UP<::Layout::ITiledAlgorithm>&& algo) {
    reinterpret_cast<UpdateTiledAlgoFn>(g_updateTiledAlgoHook->m_original)(self, std::move(algo));
    if (const auto SPACE = self->space())
        ModeSync::layoutChanged(SPACE->workspace());
}

CFunctionHook* hookUpdateTiledAlgo(HANDLE handle) {
    for (const auto& fn : HyprlandAPI::findFunctionsByName(handle, "updateTiledAlgo")) {
        if (fn.demangled.contains("CAlgorithm::updateTiledAlgo"))
            return HyprlandAPI::createFunctionHook(handle, fn.address, reinterpret_cast<void*>(&hkUpdateTiledAlgo));
    }
    return nullptr;
}

} // namespace

void install(HANDLE handle) {
    // Before the layout registers: registering it switches the workspaces that ask for it.
    g_updateTiledAlgoHook = hookUpdateTiledAlgo(handle);
    if (!g_updateTiledAlgoHook || !g_updateTiledAlgoHook->hook())
        throw std::runtime_error("hypr-floating: could not hook CAlgorithm::updateTiledAlgo");

    if (!FloatingAlgo::install(handle))
        throw std::runtime_error("hypr-floating: Hyprland has a layout named floating already");

    // Each of these is still being committed when it fires; changing the window underneath it
    // loses the change, so ModeSync applies the mode a tick later.
    auto& window = Event::bus()->m_events.window;
    g_listeners.push_back(window.open.listen([](PHLWINDOW w) {
        OwnFloat::opened(w); // what it was launched with can be told apart only now
        ModeSync::reached(w);
    }));
    g_listeners.push_back(window.moveToWorkspace.listen([](PHLWINDOW w, PHLWORKSPACE) { ModeSync::reached(w); }));
    g_listeners.push_back(window.fullscreen.listen([](PHLWINDOW w) {
        if (!Fullscreen::controller()->isFullscreen(w))
            ModeSync::reached(w);
    }));
    // A window that made its group float on its own may be the one closing.
    g_listeners.push_back(window.close.listen([](PHLWINDOW w) {
        for (const auto& m : Compat::groupMembers(w)) {
            if (m != w)
                ModeSync::reached(m);
        }
    }));
    g_listeners.push_back(Event::bus()->m_events.config.reloaded.listen([] { ModeSync::syncLater(); }));
}

void uninstall() {
    // The hook stays: Hyprland unregisters the layout, which switches workspaces through it,
    // before it removes the plugin's hooks. ModeSync ignores it once stopped.
    g_listeners.clear();
    ModeSync::stop();
    OwnFloat::forget();
}

} // namespace HyprFloating::FloatingLayout

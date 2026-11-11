#include "floatingAlgo.hpp"

#include "modeSync.hpp"
#include "../floating.hpp"

#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/tiled/dwindle/DwindleAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/target/Target.hpp>

namespace HyprFloating::FloatingAlgo {

using namespace Floating;

namespace {

// Floats every window that reaches it, except one the user un-floats here and a
// full-screen one: those are tiled the way dwindle tiles them, so a user's
// togglefloating on a floating workspace holds (until the mode next reaches the
// window) and is laid out sensibly. Only such windows ever reach the dwindle half.
class CFloatingAlgorithm : public ::Layout::Tiled::CDwindleAlgorithm {
  public:
    void newTarget(SP<::Layout::ITarget> target) override {
        arrive(target, eArrival::ARRIVED, std::nullopt);
    }

    void movedTarget(SP<::Layout::ITarget> target, std::optional<Vector2D> focalPoint) override {
        // wasTiling is set while togglefloating runs: this window was just un-floated by the user.
        arrive(target, target->wasTiling() ? eArrival::TOGGLED : eArrival::ARRIVED, focalPoint);
    }

    // Floated targets are not in the dwindle half, and it complains about removing one.
    void removeTarget(SP<::Layout::ITarget> target) override {
        const auto W = target->window();
        if (!W || getNodeFromWindow(W))
            CDwindleAlgorithm::removeTarget(target);
    }

    std::optional<std::string> layoutName() const override {
        return "floating";
    }

    // A new window is configured at the size it will float at.
    std::optional<Vector2D> predictSizeForNewTarget() override {
        const auto P = m_parent.lock();
        if (!P || !P->space())
            return std::nullopt;
        const auto& WA   = P->space()->workArea(true);
        const auto  SIZE = openSize({WA.x, WA.y, WA.w, WA.h});
        return Vector2D{SIZE.w, SIZE.h};
    }

  private:
    void tile(const SP<::Layout::ITarget>& target, eArrival how, std::optional<Vector2D> focalPoint) {
        if (how == eArrival::ARRIVED && !focalPoint)
            CDwindleAlgorithm::newTarget(target);
        else
            CDwindleAlgorithm::movedTarget(target, focalPoint);
    }

    void arrive(const SP<::Layout::ITarget>& target, eArrival how, std::optional<Vector2D> focalPoint) {
        const auto W = target->window();
        const auto P = m_parent.lock();
        // While Hyprland switches the workspace to this layout it walks the old layout's
        // tiled targets, and floating one now would erase it from that list: the switch's
        // own sync (ModeSync::layoutChanged) floats it a tick later.
        if (!W || !P || !P->space() || P->tiledAlgo().get() != this || ModeSync::onArrival(W, P->space()->workspace(), how) != eAction::FLOAT) {
            tile(target, how, focalPoint);
            return;
        }
        ModeSync::floatTarget(P, target);
    }
};

} // namespace

bool install(HANDLE handle) {
    return HyprlandAPI::addTiledAlgo(handle, "floating", &typeid(CFloatingAlgorithm), [] { return makeUnique<CFloatingAlgorithm>(); });
}

} // namespace HyprFloating::FloatingAlgo

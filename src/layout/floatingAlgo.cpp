#include "floatingAlgo.hpp"

#include "claims.hpp"
#include "../floating.hpp"

#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/tiled/dwindle/DwindleAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>

namespace HyprFloating::FloatingAlgo {

using namespace Floating;

namespace {

// Floats every window that reaches it, except the ones the user keeps tiled by
// un-floating them (and a full-screen one). Those are tiled the way dwindle tiles
// them, so a user's togglefloating on a floating workspace sticks and is laid out
// sensibly: only such windows ever reach the dwindle half.
class CFloatingAlgorithm : public ::Layout::Tiled::CDwindleAlgorithm {
  public:
    ~CFloatingAlgorithm() override {
        // The workspace has another layout now (or is going away): give back what we floated.
        Claims::syncLater();
    }

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
        const auto W  = target->window();
        const auto FS = W && Fullscreen::controller()->isFullscreen(W);

        const auto P = m_parent.lock();
        if (onArrival(how, FS) == eArrivalVerdict::TILE || !P) {
            tile(target, how, focalPoint);
            Claims::sync(target);
            return;
        }

        // Hyprland is switching the workspace to this layout: it is walking the old
        // layout's tiled targets, and floating one now would erase it from that list.
        if (P->tiledAlgo().get() != this) {
            tile(target, how, focalPoint);
            Claims::claimLater(target);
            return;
        }

        Claims::claim(P, target);
    }
};

} // namespace

bool install(HANDLE handle) {
    return HyprlandAPI::addTiledAlgo(handle, "floating", &typeid(CFloatingAlgorithm), [] { return makeUnique<CFloatingAlgorithm>(); });
}

} // namespace HyprFloating::FloatingAlgo

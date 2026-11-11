// Unit tests of the floating layout's bookkeeping. Plain C++, no Hyprland.
#include "../../src/floating.hpp"

#include <cstdio>
#include <string>
#include <vector>

using namespace HyprFloating::Floating;

static int g_failed = 0;

static void check(bool ok, const std::string& what) {
    std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what.c_str());
    g_failed += !ok;
}

static bool same(const SBox& a, const SBox& b) {
    return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h;
}

static SWindow window(eWorkspace ws, bool floating, bool claimed, bool pinned = false, bool marked = false) {
    return {.workspace = ws, .floating = floating, .pinned = pinned, .claimed = claimed, .marked = marked};
}

int main() {
    // --- the size and place of a window the layout floats
    const SBox WA{0, 0, 1920, 1080};
    check(same(openSize(WA), {0, 0, 1100, 734}), "1920x1080: 1100 wide (capped), 68% high");
    check(same(openSize({0, 0, 1000, 800}), {0, 0, 640, 544}), "a small area: 64% x 68%");
    check(same(openSize({0, 0, 3840, 2160}), {0, 0, 1100, 760}), "a big area: capped at 1100x760");
    check(same(openBox(WA, 2), {410, 173, 1100, 734}), "the middle step is centred");
    check(openBox(WA, 0).x == openBox(WA, 2).x - 48 && openBox(WA, 4).y == openBox(WA, 2).y + 48, "steps run from -48 to +48 on both axes");
    check(openBox({100, 50, 1000, 800}, 2).x == 100 + 500 - 320 && openBox({100, 50, 1000, 800}, 2).y == 50 + 400 - 272, "the box follows the work area's origin");
    int c = 0, seen = 0;
    for (int i = 0; i < 12; ++i, c = nextCascade(c))
        seen |= 1 << c;
    check(seen == (1 << CASCADE_STEPS) - 1 && nextCascade(CASCADE_STEPS - 1) == 0, "the cascade visits every step and wraps");

    // --- a tiled window reaching a floating workspace
    check(onArrival(eArrival::ARRIVED, false) == eArrivalVerdict::CLAIM, "a new window, or one carried in, is floated");
    check(onArrival(eArrival::TOGGLED, false) == eArrivalVerdict::TILE, "a window the user un-floated stays tiled");
    check(onArrival(eArrival::ARRIVED, true) == eArrivalVerdict::TILE, "a full-screen window is left as it is");

    // --- a window against its workspace
    using enum eWorkspace;
    auto s = sync(window(FLOATING, true, true));
    check(!s.retile && s.claimed && s.marked, "claimed on a floating workspace: stays, claimed and marked");
    s = sync(window(FLOATING, true, false));
    check(!s.retile && !s.claimed && s.marked, "floating on its own on a floating workspace: marked, not claimed");
    s = sync(window(FLOATING, false, false));
    check(!s.retile && !s.claimed && s.marked, "user-tiled on a floating workspace: marked, not claimed");
    s = sync(window(FLOATING, false, true));
    check(!s.claimed && s.marked, "no claim survives a window being tiled");

    s = sync(window(TILED, true, true));
    check(s.retile && !s.claimed && !s.marked, "claimed and floating where the workspace tiles: tile again, unmarked");
    s = sync(window(TILED, true, false, false, true));
    check(!s.retile && !s.claimed && !s.marked, "floating on its own where the workspace tiles: stays floating, unmarked");
    s = sync(window(TILED, false, false));
    check(!s.retile && !s.claimed, "tiled where the workspace tiles: nothing");
    s = sync(window(TILED, true, true, true));
    check(!s.retile && !s.claimed, "a pinned claimed window stays floating (tiling would unpin it) and loses its claim");
    s = sync(window(TILED, false, true));
    check(!s.retile && !s.claimed, "a claimed window that is already tiled only loses its claim");

    s = sync(window(SPECIAL, true, true, false, true));
    check(!s.retile && s.claimed && s.marked, "special workspace: claim and mark are kept");
    s = sync(window(SPECIAL, false, false));
    check(!s.retile && !s.claimed && !s.marked, "special workspace, unclaimed: nothing");

    // --- round trips: floating -> tiled -> floating, and what is left floating
    struct SW {
        SWindow w;
        bool    userFloated;
    };
    std::vector<SW> ws = {{window(FLOATING, true, true), false}, {window(FLOATING, true, false), true}};
    for (auto& e : ws) { // the workspace stops floating
        e.w.workspace = TILED;
        const auto R  = sync(e.w);
        e.w.floating  = e.w.floating && !R.retile;
        e.w.claimed   = R.claimed;
        e.w.marked    = R.marked;
    }
    check(!ws[0].w.floating && ws[1].w.floating && !ws[0].w.marked && !ws[1].w.marked, "the workspace stops floating: ours tile, the user's stay floating, nothing stays marked");
    for (auto& e : ws) { // it floats again: tiled windows are claimed
        e.w.workspace = FLOATING;
        if (!e.w.floating && onArrival(eArrival::ARRIVED, false) == eArrivalVerdict::CLAIM)
            e.w.floating = e.w.claimed = true;
        const auto R = sync(e.w);
        e.w.claimed  = R.claimed;
        e.w.marked   = R.marked;
    }
    check(ws[0].w.floating && ws[0].w.claimed && ws[1].w.floating && !ws[1].w.claimed && ws[0].w.marked && ws[1].w.marked, "floats again: the same windows are claimed, the user's still is not, both marked");

    std::puts(g_failed ? "FAILED" : "all PASS");
    return g_failed != 0;
}

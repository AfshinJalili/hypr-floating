// Unit tests of the floating layout's rule. Plain C++, no Hyprland.
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

static SWindow window(eWorkspace ws, bool floating, bool own = false) {
    return {.workspace = ws, .floating = floating, .ownFloat = own};
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

    // --- the mode reaches a window
    using enum eWorkspace;
    using enum eAction;
    check(applyMode(window(FLOATING, false)) == FLOAT, "tiled on a floating workspace: floats");
    check(applyMode(window(FLOATING, true)) == KEEP, "floating on a floating workspace: stays");
    check(applyMode(window(TILED, true)) == TILE, "floating on a tiled workspace: tiles, whoever floated it (the layout, the user, Omarchy's Lua)");
    check(applyMode(window(TILED, false)) == KEEP, "tiled on a tiled workspace: stays");
    check(applyMode(window(TILED, true, true)) == KEEP, "a dialog or rule-floated window on a tiled workspace: stays floating");
    check(applyMode(window(TILED, false, true)) == FLOAT, "a dialog the user tiled: floats again when the mode reaches it");
    check(applyMode(window(FLOATING, true, true)) == KEEP, "a dialog on a floating workspace: stays floating");
    check(applyMode(window(SPECIAL, true)) == KEEP && applyMode(window(SPECIAL, false)) == KEEP, "a special workspace (minimized): keeps the state the window arrived with");
    auto pinned = window(TILED, true);
    pinned.pinned = true;
    check(applyMode(pinned) == KEEP, "a pinned window is left as it is (tiling would unpin it)");
    auto full = window(TILED, true);
    full.fullscreen = true;
    check(applyMode(full) == KEEP, "a full-screen floating window on a tiled workspace: left as it is");
    full = window(FLOATING, false);
    full.fullscreen = true;
    check(applyMode(full) == KEEP, "a full-screen tiled window on a floating workspace: left as it is");

    // --- floating by its own nature
    check(floatsOnItsOwn({.requested = true}), "a dialog, a transient, a fixed-size window: floats on its own");
    check(floatsOnItsOwn({.rules = true}), "a window rule that matches it now floats it (an app's float rule): floats on its own");
    check(!floatsOnItsOwn({}), "no rule matches it now (one scoped to the workspace it opened on, or since removed): does not");
    check(!floatsOnItsOwn({.rules = false}), "a rule tiles it: does not");
    check(floatsOnItsOwn({.launchRule = true}), "launched with [float]: floats on its own, though Hyprland dropped the rule");
    check(!floatsOnItsOwn({.launchRule = false, .rules = true}), "launched with [tile] over a float rule: the launch rule is read last, as Hyprland reads it");
    check(floatsOnItsOwn({.requested = true, .launchRule = false}), "a dialog launched with [tile]: still floats on its own");
    check(launchRule(true, std::nullopt) == true, "Hyprland read float, no registered rule says so: a launch rule floated it");
    check(launchRule(false, true) == false, "Hyprland read tile over a float rule: a launch rule tiled it");
    check(launchRule(true, true) == std::nullopt, "Hyprland read what the registered rules say (a workspace's float rule): nothing to keep");
    check(launchRule(std::nullopt, std::nullopt) == std::nullopt, "no rule at all: nothing to keep");
    check(launchRule(std::nullopt, true) == std::nullopt, "a rule matches only since it mapped: not a launch rule");

    // --- a tiled window reaching the floating layout
    check(onArrival(eArrival::ARRIVED, window(FLOATING, false)) == FLOAT, "a new window, one carried in, one there as the workspace starts floating: floats");
    check(onArrival(eArrival::TOGGLED, window(FLOATING, false)) == KEEP, "the user un-floated it here: stays tiled until the mode next reaches it");
    check(onArrival(eArrival::ARRIVED, full) == KEEP, "a full-screen window arriving: left as it is");
    check(onArrival(eArrival::ARRIVED, window(SPECIAL, false)) == KEEP, "a window minimized to a special workspace whose layout floats: stays tiled");

    // --- the mark
    check(marked(FLOATING, false) && !marked(TILED, true) && marked(SPECIAL, true) && !marked(SPECIAL, false), "the mark: on a floating workspace, off elsewhere, kept on a special one");

    // --- a workspace's windows through the mode cycle dwindle -> scrolling -> floating -> dwindle
    struct SW {
        SWindow w;
        bool    wantsFloating; // after floating -> dwindle
    };
    std::vector<SW> ws = {
        {window(TILED, false), false},      // tiled
        {window(TILED, true), false},       // floated by hand
        {window(TILED, true, true), true},  // a dialog
    };
    auto reach = [&](eWorkspace to) {
        for (auto& e : ws) {
            e.w.workspace = to;
            const auto A  = applyMode(e.w);
            e.w.floating  = A == FLOAT || (A == KEEP && e.w.floating);
        }
    };
    reach(TILED); // dwindle -> scrolling
    check(!ws[0].w.floating && !ws[1].w.floating && ws[2].w.floating, "dwindle -> scrolling: the hand-floated window tiles, the dialog floats");
    reach(FLOATING);
    check(ws[0].w.floating && ws[1].w.floating && ws[2].w.floating, "scrolling -> floating: every window floats");
    ws[0].w.floating = false; // the user tiles one by hand
    reach(TILED);
    check(!ws[0].w.floating && !ws[1].w.floating && ws[2].w.floating, "floating -> dwindle: every window tiles but the dialog");

    std::puts(g_failed ? "FAILED" : "all PASS");
    return g_failed != 0;
}

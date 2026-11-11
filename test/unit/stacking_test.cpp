// Unit tests of the stacking rule. Plain C++, no Hyprland.
#include "../../src/stacking.hpp"

#include <cstdio>
#include <string>

using namespace HyprFloating::Stacking;
using enum eVerdict;

static int g_failed = 0;

static void check(bool ok, const std::string& what) {
    std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what.c_str());
    g_failed += !ok;
}

static SWindow floating() { return {.floating = true}; }
static SWindow tiled() { return {}; }
static SWindow pinned() { return {.floating = true, .pinned = true}; }
static SWindow fullscreen(bool floats) { return {.floating = floats, .fullscreen = true}; }

static bool is(const std::vector<SWindow>& windows, const std::vector<eVerdict>& want) {
    const auto R = evaluate(windows);
    return R.applies && R.verdicts == want;
}

int main() {
    check(!evaluate({}).applies, "no windows: stock");
    check(!evaluate({floating(), floating()}).applies, "no full-screen window: stock");
    check(!evaluate({floating(), fullscreen(false), floating()}).applies, "tiled full-screen window: stock");

    check(is({fullscreen(true)}, {LEAVE}), "a lone floating full-screen window");
    check(is({floating(), fullscreen(true), floating()}, {UNDER, LEAVE, OVER}), "below is hidden, above is allowed");
    check(is({floating(), floating(), fullscreen(true)}, {UNDER, UNDER, LEAVE}), "everything below is hidden");
    check(is({fullscreen(true), floating(), floating()}, {LEAVE, OVER, OVER}), "everything above is allowed");
    check(is({pinned(), fullscreen(true), pinned()}, {LEAVE, LEAVE, LEAVE}), "pinned windows are left alone, below or above");
    check(is({tiled(), fullscreen(true), tiled()}, {LEAVE, LEAVE, LEAVE}), "tiled windows are left alone");
    check(is({floating(), pinned(), fullscreen(true), tiled(), floating()}, {UNDER, LEAVE, LEAVE, LEAVE, OVER}), "a mix");

    // Raising a window changes its verdict from UNDER to OVER: the invariant the plugin keeps after every restack.
    check(is({fullscreen(true), floating()}, {LEAVE, OVER}) && is({floating(), fullscreen(true)}, {UNDER, LEAVE}), "swapping the order swaps the verdicts");

    check(needsRaiseOnFocus({floating(), fullscreen(true)}, 0), "focus below a floating full-screen window raises");
    check(!needsRaiseOnFocus({fullscreen(true), floating()}, 1), "focus above it does not");
    check(!needsRaiseOnFocus({floating(), fullscreen(true)}, 1), "focus on the full-screen window does not");
    check(!needsRaiseOnFocus({pinned(), fullscreen(true)}, 0), "focus on a pinned window does not");
    check(!needsRaiseOnFocus({tiled(), fullscreen(true)}, 0), "focus on a tiled window does not");
    check(!needsRaiseOnFocus({floating(), fullscreen(false)}, 0), "tiled full-screen window: stock");
    check(!needsRaiseOnFocus({floating(), floating()}, 0), "no full-screen window: stock");
    check(!needsRaiseOnFocus({floating()}, 3), "an index out of range does not");

    return g_failed ? 1 : 0;
}

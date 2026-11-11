---------------------------- MODULE Stacking ----------------------------
(***************************************************************************)
(* One Hyprland workspace with a few windows, a stacking order, at most    *)
(* one full-screen or maximized window, and focus. The windows are         *)
(* overlapping: a click at a point they all cover reaches one of them.     *)
(*                                                                         *)
(* The model follows Hyprland 0.56's code:                                 *)
(*  - m_allowedOverFullscreen ("over") is a flag per window.               *)
(*  - The renderer draws every floating window with the flag set over the  *)
(*    full-screen window, whatever the stacking order (Renderer.cpp).      *)
(*  - Pointer input visits floating windows from the top of the stacking   *)
(*    order, skipping those without the flag; the full-screen window has   *)
(*    the flag, so it takes the click when it is above them                *)
(*    (ViewHitTester.cpp).                                                 *)
(*  - Focusing a floating window sets its flag without raising it         *)
(*    (FocusState.cpp); moveToZ sets only the moved window's flag          *)
(*    (WindowState.cpp); entering full screen clears every other flag,     *)
(*    leaving sets them all (FullscreenHandler.cpp).                       *)
(*                                                                         *)
(* Variant says which of the plugin's rules are on:                        *)
(*   "stock"  none: Hyprland as it is                                      *)
(*   "rule1"  rule 1 only: after every stacking or full-screen change,    *)
(*            the flag of each floating window is set iff the window is    *)
(*            above a floating full-screen window                          *)
(*   "full"   rules 1 and 2: a floating window that is focused below a    *)
(*            floating full-screen window is raised                        *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Windows, Variant, NONE


VARIABLES
    order,    \* the open windows, bottom to top
    floating, \* fixed per window: floats, or is tiled
    pinned,   \* fixed per window: pinned (floating windows only)
    fs,       \* the full-screen or maximized window, or NONE
    focus,    \* the focused window, or NONE
    over,     \* Hyprland's m_allowedOverFullscreen, per window
    dropped   \* Hyprland dropped the focus of a window a focus event had just hidden

vars == <<order, floating, pinned, fs, focus, over, dropped>>

OpenSet(o) == {o[i] : i \in 1..Len(o)}
Idx(o, w)  == CHOOSE i \in 1..Len(o) : o[i] = w
TopBy(o, S) == CHOOSE w \in S : \A v \in S \ {w} : Idx(o, v) < Idx(o, w)

Raised(o, w)  == LET F(x) == x # w IN Append(SelectSeq(o, F), w)
Lowered(o, w) == LET F(x) == x # w IN <<w>> \o SelectSeq(o, F)
Removed(o, w) == LET F(x) == x # w IN SelectSeq(o, F)

\* The plugin's rules apply when the full-screen window floats and is not pinned
\* (Hyprland takes input for a pinned window before any other, whatever the
\* stacking order, so nothing can be clicked over a pinned full-screen window).
FloatsAt(f) == f # NONE /\ floating[f] /\ ~pinned[f]

\* CWindow::isAllowedOverFullscreen: the window is not hidden by the full-screen window f.
Allowed(f, ov, w) == w = f \/ pinned[w] \/ ov[w]
Blocked(f, ov, w) == f # NONE /\ ~Allowed(f, ov, w)

---------------------------------------------------------------------------
(* What the screen shows and where a click goes, for the windows S that    *)
(* overlap at one point. S holds f when there is a full-screen window f.   *)

\* Floating windows first, in stacking order; then the tiled one.
\* With a full-screen window: the floating windows with the flag, in stacking
\* order, over the full-screen window.
DrawnTop(o, f, ov, S) ==
    IF f = NONE
    THEN LET Fl == {w \in S : floating[w]}
         IN  IF Fl # {} THEN TopBy(o, Fl) ELSE CHOOSE t \in S : TRUE
    ELSE LET D == {w \in S : floating[w] /\ w # f /\ Allowed(f, ov, w)}
         IN  IF D # {} THEN TopBy(o, D) ELSE f

\* Pinned windows first; then the floating ones from the top of the stacking
\* order that are not hidden (the full-screen window is one of them, at its
\* place in the order); then the tiled one.
ClickTarget(o, f, ov, S) ==
    LET P == {w \in S : floating[w] /\ pinned[w]}
        C == {w \in S : floating[w] /\ ~pinned[w] /\ (f = NONE \/ Allowed(f, ov, w))}
        T == {w \in S : ~floating[w]}
    IN  IF P # {} THEN TopBy(o, P)
        ELSE IF C # {} THEN TopBy(o, C)
        ELSE CHOOSE t \in T : TRUE

\* The windows a click can land on together: they all overlap, the full-screen
\* window covers them, and tiled windows do not overlap each other.
ValidSets ==
    {S \in SUBSET OpenSet(order) :
        /\ S # {}
        /\ (fs # NONE => fs \in S)
        /\ Cardinality({w \in S : ~floating[w]}) <= 1}

---------------------------------------------------------------------------
(* The plugin                                                              *)

\* Rule 1: with a floating full-screen window f, a floating window that is not
\* pinned is allowed over it iff it is above it.
Recompute(o, f, ov) ==
    [w \in Windows |->
        IF FloatsAt(f) /\ w \in OpenSet(o) /\ floating[w] /\ ~pinned[w] /\ w # f
        THEN Idx(o, w) > Idx(o, f)
        ELSE ov[w]]

\* Every action ends here with the state it computed (o, f, fo, ov). Hyprland drops
\* the focus of a window as soon as it hides it (setInputBlocked), so a focused
\* window the stock effect hid is unfocused first. Then the plugin applies rule 1,
\* and a focused window that rule 1 hides loses focus too: `track` says the action
\* was a focus event, where that is the bug rule 2 prevents (an explicit raise or
\* lower of a window may hide the focused one).
Post(V, o, f, fo, ov, track) ==
    LET fo0 == IF fo # NONE /\ Blocked(f, ov, fo) THEN NONE ELSE fo
        ov1 == IF V # "stock" THEN Recompute(o, f, ov) ELSE ov
        hid == fo0 # NONE /\ Blocked(f, ov1, fo0)
    IN  /\ order'   = o
        /\ fs'      = f
        /\ over'    = ov1
        /\ focus'   = IF hid THEN NONE ELSE fo0
        /\ dropped' = (dropped \/ (hid /\ track))

\* After a focus event on fo; rule 2 raises a floating window focused below a
\* floating full-screen window.
AfterFocus(V, o, f, fo, ov) ==
    IF /\ V = "full" /\ FloatsAt(f) /\ fo # f /\ floating[fo] /\ ~pinned[fo]
       /\ Idx(o, fo) < Idx(o, f)
    THEN Post(V, Raised(o, fo), f, fo, [ov EXCEPT ![fo] = TRUE], TRUE)
    ELSE Post(V, o, f, fo, ov, TRUE)

AllAllowed(ov) == [w \in Windows |-> IF pinned[w] THEN ov[w] ELSE TRUE]

---------------------------------------------------------------------------
(* Hyprland's actions. Each is Hyprland's own effect, then the plugin's.   *)

\* A window opens at the top. A floating one has the flag. A tiled one opens
\* only without a full-screen window (Hyprland's settings decide otherwise).
OpenWin(V, w) ==
    /\ w \notin OpenSet(order)
    /\ floating[w] \/ fs = NONE
    /\ UNCHANGED <<floating, pinned>>
    /\ AfterFocus(V, Append(order, w), fs, w, [over EXCEPT ![w] = floating[w] \/ fs = NONE])

\* Closing the full-screen window clears the full-screen state: every flag is set.
CloseWin(V, w) ==
    /\ w \in OpenSet(order)
    /\ UNCHANGED <<floating, pinned>>
    /\ LET f  == IF fs = w THEN NONE ELSE fs
           ov == IF fs = w THEN AllAllowed(over) ELSE over
       IN  Post(V, Removed(order, w), f, IF focus = w THEN NONE ELSE focus, ov, FALSE)

\* Leaving full screen sets every flag. Entering it clears every flag but the
\* full-screen window's own: a focused window other than that one loses focus.
ToggleFullscreen(V, w) ==
    /\ w \in OpenSet(order)
    /\ UNCHANGED <<floating, pinned>>
    /\ IF fs = w
       THEN Post(V, order, NONE, focus, AllAllowed(over), FALSE)
       ELSE Post(V, order, w, focus, [x \in Windows |-> IF x = w \/ pinned[x] THEN over[x] ELSE FALSE], FALSE)

\* hl.dsp.focus. A floating window gets the flag, and is not raised. A tiled
\* window under full screen ends it (misc:on_focus_under_fullscreen = 2).
FocusWin(V, w) ==
    /\ w \in OpenSet(order)
    /\ UNCHANGED <<floating, pinned>>
    /\ IF fs = NONE \/ w = fs
       THEN AfterFocus(V, order, fs, w, over)
       ELSE IF floating[w]
            THEN AfterFocus(V, order, fs, w, [over EXCEPT ![w] = TRUE])
            ELSE AfterFocus(V, order, NONE, w, AllAllowed(over))

\* A click at a point where the windows S overlap: the window it reaches takes
\* focus, and a floating one is raised.
Click(V, S) ==
    /\ S \in ValidSets
    /\ UNCHANGED <<floating, pinned>>
    /\ LET t   == ClickTarget(order, fs, over, S)
           ov1 == IF fs # NONE /\ floating[t] THEN [over EXCEPT ![t] = TRUE] ELSE over
           o   == IF floating[t] THEN Raised(order, t) ELSE order
       IN  AfterFocus(V, o, fs, t, ov1)

\* hl.dsp.window.bring_to_top, and what raises a window without focusing it.
RaiseWin(V, w) ==
    /\ w \in OpenSet(order) /\ floating[w]
    /\ UNCHANGED <<floating, pinned>>
    /\ Post(V, Raised(order, w), fs, focus, [over EXCEPT ![w] = TRUE], FALSE)

LowerWin(V, w) ==
    /\ w \in OpenSet(order) /\ floating[w]
    /\ UNCHANGED <<floating, pinned>>
    /\ Post(V, Lowered(order, w), fs, focus, [over EXCEPT ![w] = FALSE], FALSE)

Next(V) ==
    \/ \E w \in Windows : OpenWin(V, w) \/ CloseWin(V, w) \/ ToggleFullscreen(V, w)
                          \/ FocusWin(V, w) \/ RaiseWin(V, w) \/ LowerWin(V, w)
    \/ \E S \in SUBSET Windows : Click(V, S)

Init ==
    /\ order    = <<>>
    /\ floating \in [Windows -> BOOLEAN]
    /\ pinned   \in {p \in [Windows -> BOOLEAN] : \A w \in Windows : p[w] => floating[w]}
    /\ fs       = NONE
    /\ focus    = NONE
    /\ over     = [w \in Windows |-> TRUE]
    /\ dropped  = FALSE

Spec == Init /\ [][Next(Variant)]_vars

---------------------------------------------------------------------------
(* What must hold                                                          *)

TypeOK ==
    /\ order \in Seq(Windows)
    /\ Cardinality(OpenSet(order)) = Len(order)
    /\ fs \in Windows \cup {NONE}
    /\ (fs # NONE => fs \in OpenSet(order))
    /\ focus \in Windows \cup {NONE}
    /\ over \in [Windows -> BOOLEAN]

FSFloats == FloatsAt(fs)

DrawnOverFS(w)    == DrawnTop(order, fs, over, {w, fs}) = w
ClickableOverFS(w) == ClickTarget(order, fs, over, {w, fs}) = w
AboveFS(w)        == Idx(order, w) > Idx(order, fs)

\* (1) With a floating full-screen window, a floating window that is not pinned
\* is drawn over it iff it takes clicks over it iff it is above it.
DrawnClickableAbove ==
    FSFloats =>
        \A w \in OpenSet(order) :
            (floating[w] /\ ~pinned[w] /\ w # fs) =>
                /\ (DrawnOverFS(w) <=> ClickableOverFS(w))
                /\ (ClickableOverFS(w) <=> AboveFS(w))

\* The bug itself: a floating window drawn over the full-screen window must take
\* the clicks there, not leave them to the full-screen window below it.
DrawnImpliesClickable ==
    FSFloats =>
        \A w \in OpenSet(order) :
            (floating[w] /\ ~pinned[w] /\ w # fs) => (DrawnOverFS(w) => ClickableOverFS(w))

\* (1, for all windows at once) What is drawn on top at a point is what the click
\* there reaches, for windows that are not pinned (Hyprland puts pinned windows
\* first for input, but draws them in stacking order).
TopDrawnIsTopClicked ==
    \A S \in ValidSets :
        (\A w \in S : ~pinned[w]) => DrawnTop(order, fs, over, S) = ClickTarget(order, fs, over, S)

\* (2) Focus never lands on a window the full-screen window hides.
FocusNeverHidden == ~dropped

\* (3) Tiled full screen is stock: a step that does not end with a floating
\* full-screen window is a step stock Hyprland takes.
TiledFullscreenIsStock == [][~(FloatsAt(fs')) => Next("stock")]_vars

=========================================================================

---------------------------- MODULE Floating ----------------------------
(***************************************************************************)
(* The float/tile bookkeeping of the floating layout (src/floating.hpp):   *)
(* which windows the layout floated, and which tile again when a          *)
(* workspace stops floating or the plugin unloads.                         *)
(*                                                                         *)
(* A workspace has a requested layout, "floating" or "tiled". It floats    *)
(* its windows only while the plugin is loaded. A window floats in one of *)
(* three ways, its `origin`:                                               *)
(*   "tiled"   it does not float                                           *)
(*   "own"     it floats on its own: a float rule, a dialog, the user's     *)
(*             togglefloating. The layout never tiles it again.             *)
(*   "plugin"  the layout floated it. It tiles again when the workspace     *)
(*             stops floating or the plugin unloads.                        *)
(* `origin` is the ground truth, only the model sees it. `claimed` is what *)
(* the plugin knows (a tag on the window); the checks are that it knows    *)
(* exactly the windows the layout floated.                                 *)
(*                                                                         *)
(* A window of a group floats and tiles with the group, and a window that *)
(* opens into a group never reaches the layout, so the plugin has to give  *)
(* it the group's claim itself.                                            *)
(*                                                                         *)
(* Variant says which of the plugin's rules are on:                        *)
(*   "full"     all of them                                                *)
(*   "refloat"  without: togglefloating on a floating workspace sticks     *)
(*              (the layout floats the window again at once)               *)
(*   "noexit"   without: unloading tiles again what the layout floated     *)
(*   "headtag"  without: floating a group claims every member (only the    *)
(*              head)                                                      *)
(*   "nogroup"  without: a window opening into a claimed group is claimed  *)
(*   "all"      without: only the claimed windows tile again (every        *)
(*              floating window does)                                      *)
(*                                                                         *)
(* Not modelled: special workspaces (a minimized window keeps its state),  *)
(* pinned and full-screen windows (tiling would unpin them; a full-screen  *)
(* window is left as it is), several monitors, the order of windows, the   *)
(* tag syncing that Hyprland's events delay by a tick.                     *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS Windows, Workspaces, Groups, Variant, NONE

VARIABLES
    ws,       \* per window: its workspace, or NONE when it is not open
    origin,   \* per window: "tiled", "own" or "plugin"
    claimed,  \* per window: the plugin's mark (omarchy-mode-floated is its twin)
    explicit, \* per window: the user un-floated it (togglefloating), and it has stayed tiled since
    grp,      \* per window: its group, or NONE
    layout,   \* per workspace: the requested layout
    loaded    \* the plugin is loaded

vars == <<ws, origin, claimed, explicit, grp, layout, loaded>>

OpenW == {w \in Windows : ws[w] # NONE}
Floats(l, ld, x) == ld /\ l[x] = "floating"      \* workspace x floats its windows
Members(g, w) == IF g[w] = NONE THEN {w} ELSE {v \in OpenW : g[v] = g[w]}
Head(S) == CHOOSE v \in S : TRUE

---------------------------------------------------------------------------
(* What the plugin does to windows after anything changed: the one place   *)
(* that floats and tiles. It takes the world as it would be (workspaces w, *)
(* layouts l, loaded ld) and the windows' marks.                           *)

Sync(w, l, ld, o, c, e) ==
    LET Tile(v)  == \E u \in Members(grp, v) :
                        IF Variant = "all" THEN o[u] # "tiled" ELSE c[u]     \* tile the target again
        NewO(v)  == IF w[v] = NONE THEN "tiled"
                    ELSE IF Floats(l, ld, w[v])
                         THEN IF o[v] = "tiled" /\ ~e[v] THEN "plugin" ELSE o[v]
                         ELSE IF Tile(v) THEN "tiled" ELSE o[v]
        NewC(v)  == IF NewO(v) = "tiled" THEN FALSE                           \* no claim survives being tiled
                    ELSE IF o[v] = "tiled" /\ NewO(v) = "plugin"
                         THEN (Variant = "headtag" => v = Head(Members(grp, v)))
                         ELSE c[v]
    IN  [o |-> [v \in Windows |-> NewO(v)],
         c |-> [v \in Windows |-> NewC(v)],
         e |-> [v \in Windows |-> IF NewO(v) # "tiled" THEN FALSE ELSE e[v]]]

Settle(w, l, ld, e) ==
    LET R == Sync(w, l, ld, origin, claimed, e)
    IN  /\ origin' = R.o /\ claimed' = R.c /\ explicit' = R.e

---------------------------------------------------------------------------
(* Actions                                                                 *)

\* A window opens on x: alone (floating at once if a rule says so, otherwise the
\* layout floats it when x floats), or into an existing group g on x, where it
\* takes the group's state without reaching the layout.
OpenWin(w, x, g, rule) ==
    /\ ws[w] = NONE
    /\ ws' = [ws EXCEPT ![w] = x]
    /\ IF g = NONE
       THEN /\ grp' = grp
            /\ origin' = [origin EXCEPT ![w] = IF rule THEN "own" ELSE IF Floats(layout, loaded, x) THEN "plugin" ELSE "tiled"]
            /\ claimed' = [claimed EXCEPT ![w] = ~rule /\ Floats(layout, loaded, x)]
       ELSE /\ \E h \in OpenW : ws[h] = x /\ grp[h] = g
            /\ ~rule
            /\ LET h == CHOOSE h \in OpenW : ws[h] = x /\ grp[h] = g
               IN  /\ grp' = [grp EXCEPT ![w] = g]
                   /\ origin' = [origin EXCEPT ![w] = origin[h]]
                   /\ claimed' = [claimed EXCEPT ![w] = IF Variant = "nogroup" THEN FALSE ELSE claimed[h]]
    /\ explicit' = [explicit EXCEPT ![w] = IF g = NONE THEN FALSE ELSE explicit[CHOOSE h \in OpenW : ws[h] = x /\ grp[h] = g]]
    /\ UNCHANGED <<layout, loaded>>

\* A window becomes a group of its own: others can open into it.
MakeGroup(w, g) ==
    /\ ws[w] # NONE /\ grp[w] = NONE
    /\ \A v \in Windows : grp[v] # g
    /\ grp' = [grp EXCEPT ![w] = g]
    /\ UNCHANGED <<ws, origin, claimed, explicit, layout, loaded>>

CloseWin(w) ==
    /\ ws[w] # NONE
    /\ ws' = [ws EXCEPT ![w] = NONE]
    /\ grp' = [grp EXCEPT ![w] = NONE]
    /\ origin' = [origin EXCEPT ![w] = "tiled"]
    /\ claimed' = [claimed EXCEPT ![w] = FALSE]
    /\ explicit' = [explicit EXCEPT ![w] = FALSE]
    /\ UNCHANGED <<layout, loaded>>

\* The user's togglefloating, on the whole group when w is in one.
UserToggle(w) ==
    /\ ws[w] # NONE
    /\ LET S == Members(grp, w)
           x == ws[w]
       IN IF origin[w] # "tiled"
          THEN IF Variant = "refloat" /\ Floats(layout, loaded, x)
               THEN \* the layout floats it again at once: the user's choice is lost
                    /\ origin' = [v \in Windows |-> IF v \in S THEN "plugin" ELSE origin[v]]
                    /\ claimed' = [v \in Windows |-> IF v \in S THEN TRUE ELSE claimed[v]]
                    /\ explicit' = [v \in Windows |-> IF v \in S THEN TRUE ELSE explicit[v]]
               ELSE /\ origin' = [v \in Windows |-> IF v \in S THEN "tiled" ELSE origin[v]]
                    /\ claimed' = [v \in Windows |-> IF v \in S THEN FALSE ELSE claimed[v]]
                    /\ explicit' = [v \in Windows |-> IF v \in S THEN TRUE ELSE explicit[v]]
          ELSE /\ origin' = [v \in Windows |-> IF v \in S THEN "own" ELSE origin[v]]
               /\ claimed' = [v \in Windows |-> IF v \in S THEN FALSE ELSE claimed[v]]
               /\ explicit' = [v \in Windows |-> IF v \in S THEN FALSE ELSE explicit[v]]
    /\ UNCHANGED <<ws, grp, layout, loaded>>

\* A window, with its group, is carried to workspace x. It arrives anew.
MoveWin(w, x) ==
    /\ ws[w] # NONE /\ ws[w] # x
    /\ LET S  == Members(grp, w)
           w1 == [v \in Windows |-> IF v \in S THEN x ELSE ws[v]]
           e1 == [v \in Windows |-> IF v \in S THEN FALSE ELSE explicit[v]]
       IN /\ ws' = w1
          /\ Settle(w1, layout, loaded, e1)
    /\ UNCHANGED <<grp, layout, loaded>>

\* The workspace rule's layout changes (hl.workspace_rule), live.
SetLayout(x, l) ==
    /\ layout[x] # l
    /\ LET l1 == [layout EXCEPT ![x] = l]
           e1 == [v \in Windows |-> IF ws[v] = x /\ Floats(l1, loaded, x) THEN FALSE ELSE explicit[v]]
       IN /\ layout' = l1
          /\ Settle(ws, l1, loaded, e1)
    /\ UNCHANGED <<ws, grp, loaded>>

\* hyprctl plugin unload: the plugin's exit runs while it is still registered, and tiles
\* again what it floated; then no workspace floats.
Unload ==
    /\ loaded
    /\ loaded' = FALSE
    /\ IF Variant = "noexit"
       THEN UNCHANGED <<origin, claimed, explicit>>
       ELSE Settle(ws, layout, FALSE, explicit)
    /\ UNCHANGED <<ws, grp, layout>>

\* hyprctl plugin load: workspaces that ask for the layout float what they have.
Load ==
    /\ ~loaded
    /\ loaded' = TRUE
    /\ LET e1 == [v \in Windows |-> IF ws[v] # NONE /\ layout[ws[v]] = "floating" THEN FALSE ELSE explicit[v]]
       IN Settle(ws, layout, TRUE, e1)
    /\ UNCHANGED <<ws, grp, layout>>

Init ==
    /\ ws = [w \in Windows |-> NONE]
    /\ origin = [w \in Windows |-> "tiled"]
    /\ claimed = [w \in Windows |-> FALSE]
    /\ explicit = [w \in Windows |-> FALSE]
    /\ grp = [w \in Windows |-> NONE]
    /\ layout \in [Workspaces -> {"floating", "tiled"}]
    /\ loaded \in BOOLEAN

Next ==
    \/ \E w \in Windows, x \in Workspaces, g \in Groups \cup {NONE}, r \in BOOLEAN : OpenWin(w, x, g, r)
    \/ \E w \in Windows, g \in Groups : MakeGroup(w, g)
    \/ \E w \in Windows : CloseWin(w)
    \/ \E w \in Windows : UserToggle(w)
    \/ \E w \in Windows, x \in Workspaces : MoveWin(w, x)
    \/ \E x \in Workspaces, l \in {"floating", "tiled"} : SetLayout(x, l)
    \/ Unload
    \/ Load

Spec == Init /\ [][Next]_vars

---------------------------------------------------------------------------
(* What must hold                                                          *)

TypeOK ==
    /\ ws \in [Windows -> Workspaces \cup {NONE}]
    /\ origin \in [Windows -> {"tiled", "own", "plugin"}]
    /\ claimed \in [Windows -> BOOLEAN]
    /\ explicit \in [Windows -> BOOLEAN]
    /\ grp \in [Windows -> Groups \cup {NONE}]
    /\ layout \in [Workspaces -> {"floating", "tiled"}]
    /\ loaded \in BOOLEAN

\* On a floating workspace every window the user did not explicitly tile floats.
FloatingWorkspaceFloats ==
    \A w \in OpenW : Floats(layout, loaded, ws[w]) /\ ~explicit[w] => origin[w] # "tiled"

\* ... and the user's togglefloating sticks: a window the user un-floated is tiled.
ExplicitSticks ==
    \A w \in OpenW : explicit[w] => origin[w] = "tiled"

\* After a workspace stops floating or the plugin unloads, no window the layout
\* floated is still floating there: they all tiled again.
NothingFloatedWhereNothingFloats ==
    \A w \in OpenW : ~Floats(layout, loaded, ws[w]) => origin[w] # "plugin"

\* The plugin's mark is on exactly the windows the layout floated: never on a tiled
\* window, and on every member of a floated group, however it got there.
ClaimedExact ==
    \A w \in OpenW : claimed[w] <=> origin[w] = "plugin"

\* A group floats and tiles as one, with one claim.
GroupCoherent ==
    \A v, w \in OpenW : grp[v] # NONE /\ grp[v] = grp[w] =>
        /\ origin[v] = origin[w] /\ claimed[v] = claimed[w]

\* A window that floats on its own stops floating only when the user tiles it (or it closes).
UserFloatedStayFloating ==
    [][\A w \in Windows : (ws[w] # NONE /\ ws'[w] # NONE /\ origin[w] = "own" /\ origin'[w] = "tiled") => explicit'[w]]_vars

=========================================================================

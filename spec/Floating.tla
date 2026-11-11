---------------------------- MODULE Floating ----------------------------
(***************************************************************************)
(* The floating layout's float/tile rule (src/floating.hpp): a workspace's *)
(* mode is the single source of truth for whether its windows float.       *)
(*                                                                         *)
(* A workspace has a requested layout, "floating" or "tiled" (any of        *)
(* Hyprland's own). It floats its windows only while the plugin is loaded. *)
(* A window wants to float when it floats by its own nature where it is   *)
(* (`own`: a dialog or an app's float rule everywhere, a rule matched by   *)
(* workspace there only), or when its workspace floats. The plugin applies *)
(* that to a window when the mode reaches it: its workspace's layout       *)
(* changes, it opens, it moves to another workspace, it leaves full        *)
(* screen, the plugin loads or unloads. In between, the user may float or  *)
(* tile a window by hand; that holds until the mode next reaches it.       *)
(*                                                                         *)
(* `toggled` is a ghost only the model sees: the user toggled the window   *)
(* since the mode last reached it. `claimed` is what the old plugin knew:  *)
(* the windows the layout floated, the only ones it tiled again.           *)
(*                                                                         *)
(* Special is the special workspace minimized windows wait on: a window    *)
(* keeps there whatever state it arrived with, and takes its workspace's   *)
(* mode when it comes back. A full-screen window is left as it is.         *)
(*                                                                         *)
(* A window of a group floats and tiles with the group (a group is one     *)
(* layout target), and a window that opens into a group never reaches the  *)
(* layout: the plugin applies the mode to the group.                       *)
(*                                                                         *)
(* Variant says which of the plugin's rules are on:                        *)
(*   "full"     all of them                                                *)
(*   "claimed"  the old rule: only the windows the layout floated tile     *)
(*              again (a window floated by hand, or by Omarchy's Lua,      *)
(*              never does)                                                *)
(*   "nomove"   without: a window moved to another workspace takes that    *)
(*              workspace's mode                                           *)
(*   "noexit"   without: unloading tiles what a floating workspace floated *)
(*   "all"      without the own-nature exception: every window follows    *)
(*              its workspace, dialogs and float rules too                 *)
(*   "frozen"   the own nature read once, where the window opens (what     *)
(*              Hyprland keeps in static_.floating), and kept everywhere   *)
(*                                                                         *)
(* Not modelled: pinned windows (left as they are), several monitors (a    *)
(* move is a move, whichever monitor the workspace is on), the order of    *)
(* windows, and the tick Hyprland's events delay the plugin by.            *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS Windows, Workspaces, Special, Groups, Variant, NONE

VARIABLES
    ws,       \* per window: its workspace (one of Workspaces, or Special), or NONE when it is not open
    floating, \* per window: it floats
    own,      \* per window: the workspaces where it floats by its own nature (a dialog, an app's rule:
              \* all; a rule matched by workspace: those); fixed as it opens
    atOpen,   \* per window, the "frozen" variant only: a rule floated it where it opened
    fs,       \* per window: full screen or maximized
    toggled,  \* per window, ghost: the user toggled it since the mode last reached it
    claimed,  \* per window: the layout floated it (what the "claimed" variant tiles again)
    grp,      \* per window: its group, or NONE
    layout,   \* per workspace: the requested layout
    loaded    \* the plugin is loaded

vars == <<ws, floating, own, atOpen, fs, toggled, claimed, grp, layout, loaded>>

Places == Workspaces \cup {Special}
OpenW == {w \in Windows : ws[w] # NONE}
Floats(l, ld, x) == x # Special /\ ld /\ l[x] = "floating"
MembersOf(g, w) == IF g[w] = NONE THEN {w} ELSE {v \in Windows : g[v] = g[w]}
Members(w) == MembersOf(grp, w)
\* Where it is, the window floats by its own nature (o: per window, where it does); a group does
\* if a member does.
OwnTarget(g, o, wsm, w) == \E u \in MembersOf(g, w) : wsm[u] \in o[u]

\* Where the plugin sees each window float by its own nature: where it does, but in the "frozen"
\* variant, everywhere when a rule floated it where it opened (a, per window) and nowhere else.
Seen(o, a) == IF Variant = "frozen" THEN [v \in Windows |-> IF a[v] THEN Workspaces ELSE {}] ELSE o

\* What the window's workspace asks of it, with own nature o as the plugin sees it.
Want(w, wsm, l, ld, g, o) == IF Variant = "all" THEN Floats(l, ld, wsm[w])
                             ELSE OwnTarget(g, o, wsm, w) \/ Floats(l, ld, wsm[w])

---------------------------------------------------------------------------
(* The mode reaches the windows S (whole groups): the one place that       *)
(* floats and tiles. It takes the world as it would be: workspaces wsm,    *)
(* layouts l, loaded ld, groups g, own nature o (as the plugin sees it),   *)
(* full screen f. A full-screen window and one on Special are left as     *)
(* they are.                                                               *)

Reach(S, wsm, l, ld, g, o, f) ==
    LET Acts(v)  == v \in S /\ wsm[v] # NONE /\ wsm[v] # Special /\ ~f[v]
        NewF(v)  == IF wsm[v] = NONE THEN FALSE                          \* closed
                    ELSE IF ~Acts(v) THEN floating[v]
                    ELSE IF Want(v, wsm, l, ld, g, o) THEN TRUE
                    ELSE IF Variant = "claimed" THEN floating[v] /\ ~claimed[v]   \* only what the layout floated tiles
                    ELSE FALSE
        NewC(v)  == IF Variant # "claimed" \/ ~NewF(v) THEN FALSE          \* only that variant keeps claims
                    ELSE claimed[v] \/ (Acts(v) /\ ~floating[v] /\ ~OwnTarget(g, o, wsm, v))
    IN  /\ floating' = [v \in Windows |-> NewF(v)]
        /\ claimed'  = [v \in Windows |-> NewC(v)]
        /\ toggled'  = [v \in Windows |-> IF v \in S THEN FALSE ELSE toggled[v]]   \* the mode reached it: the user's toggle is over

---------------------------------------------------------------------------
(* Actions                                                                 *)

\* A window opens on x (never on Special), floating on its own on the workspaces o, alone or into
\* an existing group g on x, which then takes the mode as one.
OpenWin(w, x, o, gid) ==
    /\ ws[w] = NONE
    /\ gid # NONE => \E h \in OpenW : ws[h] = x /\ grp[h] = gid /\ ~fs[h]   \* not into a full-screen group
    /\ LET w1 == [ws EXCEPT ![w] = x]
           g1 == [grp EXCEPT ![w] = gid]
           o1 == [own EXCEPT ![w] = o]
           a1 == [atOpen EXCEPT ![w] = Variant = "frozen" /\ x \in o]
       IN /\ ws' = w1 /\ grp' = g1 /\ own' = o1 /\ atOpen' = a1
          /\ Reach(MembersOf(g1, w), w1, layout, loaded, g1, Seen(o1, a1), fs)
    /\ UNCHANGED <<fs, layout, loaded>>

\* A window becomes a group of its own: others can open into it.
MakeGroup(w, gid) ==
    /\ ws[w] # NONE /\ grp[w] = NONE
    /\ \A v \in Windows : grp[v] # gid
    /\ grp' = [grp EXCEPT ![w] = gid]
    /\ UNCHANGED <<ws, floating, own, atOpen, fs, toggled, claimed, layout, loaded>>

\* A window closes. If it was what made its group float on its own, the group no longer does: the
\* rest of the group takes the mode.
CloseWin(w) ==
    /\ ws[w] # NONE
    /\ LET g1 == [grp EXCEPT ![w] = NONE]
           o1 == [own EXCEPT ![w] = {}]
           a1 == [atOpen EXCEPT ![w] = FALSE]
           w1 == [ws EXCEPT ![w] = NONE]
           f1 == [fs EXCEPT ![w] = FALSE]
       IN /\ ws' = w1 /\ grp' = g1 /\ own' = o1 /\ atOpen' = a1 /\ fs' = f1
          /\ Reach(Members(w), w1, layout, loaded, g1, Seen(o1, a1), f1)
    /\ UNCHANGED <<layout, loaded>>

\* The user's togglefloating, on the whole group. It holds until the mode next reaches the window.
UserToggle(w) ==
    /\ ws[w] # NONE /\ ~fs[w]
    /\ LET S == Members(w)
       IN /\ floating' = [v \in Windows |-> IF v \in S THEN ~floating[w] ELSE floating[v]]
          /\ toggled' = [v \in Windows |-> IF v \in S THEN TRUE ELSE toggled[v]]
          /\ claimed' = [v \in Windows |-> IF v \in S THEN FALSE ELSE claimed[v]]
    /\ UNCHANGED <<ws, own, atOpen, fs, grp, layout, loaded>>

\* A window, with its group, is carried to x: a dispatcher, a Mission Control drop, another
\* monitor, minimizing (x = Special) and coming back from it.
MoveWin(w, x) ==
    /\ ws[w] # NONE /\ ws[w] # x
    /\ LET S  == Members(w)
           w1 == [v \in Windows |-> IF v \in S THEN x ELSE ws[v]]
       IN /\ ws' = w1
          /\ IF Variant = "nomove"
             THEN /\ toggled' = [v \in Windows |-> IF v \in S THEN FALSE ELSE toggled[v]]
                  /\ UNCHANGED <<floating, claimed>>
             ELSE Reach(S, w1, layout, loaded, grp, Seen(own, atOpen), fs)
    /\ UNCHANGED <<own, atOpen, fs, grp, layout, loaded>>

\* Full screen or maximized, of the group's shown window: the group.
EnterFullscreen(w) ==
    /\ ws[w] # NONE /\ ws[w] # Special /\ ~fs[w]
    /\ fs' = [v \in Windows |-> IF v \in Members(w) THEN TRUE ELSE fs[v]]
    /\ UNCHANGED <<ws, floating, own, atOpen, toggled, claimed, grp, layout, loaded>>

\* Leaving full screen, the window takes its workspace's mode.
LeaveFullscreen(w) ==
    /\ ws[w] # NONE /\ fs[w]
    /\ LET f1 == [v \in Windows |-> IF v \in Members(w) THEN FALSE ELSE fs[v]]
       IN /\ fs' = f1
          /\ Reach(Members(w), ws, layout, loaded, grp, Seen(own, atOpen), f1)
    /\ UNCHANGED <<ws, own, atOpen, grp, layout, loaded>>

\* The workspace's layout changes (Omarchy's toggle, a live hl.workspace_rule, a config reload):
\* every window on it takes the new mode.
SetLayout(x, l) ==
    /\ layout[x] # l
    /\ LET l1 == [layout EXCEPT ![x] = l]
       IN /\ layout' = l1
          /\ Reach({v \in OpenW : ws[v] = x}, ws, l1, loaded, grp, Seen(own, atOpen), fs)
    /\ UNCHANGED <<ws, own, atOpen, fs, grp, loaded>>

\* Workspaces with the layout stop floating when the plugin unloads (its exit runs while it is
\* still registered) and float again when it loads.
FloatingOnes == {v \in OpenW : ws[v] # Special /\ layout[ws[v]] = "floating"}

Unload ==
    /\ loaded
    /\ loaded' = FALSE
    /\ IF Variant = "noexit"
       THEN /\ toggled' = [v \in Windows |-> IF v \in FloatingOnes THEN FALSE ELSE toggled[v]]
            /\ UNCHANGED <<floating, claimed>>
       ELSE Reach(FloatingOnes, ws, layout, FALSE, grp, Seen(own, atOpen), fs)
    /\ UNCHANGED <<ws, own, atOpen, fs, grp, layout>>

Load ==
    /\ ~loaded
    /\ loaded' = TRUE
    /\ Reach(FloatingOnes, ws, layout, TRUE, grp, Seen(own, atOpen), fs)
    /\ UNCHANGED <<ws, own, atOpen, fs, grp, layout>>

Init ==
    /\ ws = [w \in Windows |-> NONE]
    /\ floating = [w \in Windows |-> FALSE]
    /\ own = [w \in Windows |-> {}]
    /\ atOpen = [w \in Windows |-> FALSE]
    /\ fs = [w \in Windows |-> FALSE]
    /\ toggled = [w \in Windows |-> FALSE]
    /\ claimed = [w \in Windows |-> FALSE]
    /\ grp = [w \in Windows |-> NONE]
    /\ layout \in [Workspaces -> {"floating", "tiled"}]
    /\ loaded \in BOOLEAN

Next ==
    \/ \E w \in Windows, x \in Workspaces, o \in SUBSET Workspaces, g \in Groups \cup {NONE} : OpenWin(w, x, o, g)
    \/ \E w \in Windows, g \in Groups : MakeGroup(w, g)
    \/ \E w \in Windows : CloseWin(w)
    \/ \E w \in Windows : UserToggle(w)
    \/ \E w \in Windows, x \in Places : MoveWin(w, x)
    \/ \E w \in Windows : EnterFullscreen(w)
    \/ \E w \in Windows : LeaveFullscreen(w)
    \/ \E x \in Workspaces, l \in {"floating", "tiled"} : SetLayout(x, l)
    \/ Unload
    \/ Load

Spec == Init /\ [][Next]_vars

---------------------------------------------------------------------------
(* What must hold                                                          *)

TypeOK ==
    /\ ws \in [Windows -> Places \cup {NONE}]
    /\ floating \in [Windows -> BOOLEAN]
    /\ own \in [Windows -> SUBSET Workspaces]
    /\ atOpen \in [Windows -> BOOLEAN]
    /\ fs \in [Windows -> BOOLEAN]
    /\ toggled \in [Windows -> BOOLEAN]
    /\ claimed \in [Windows -> BOOLEAN]
    /\ grp \in [Windows -> Groups \cup {NONE}]
    /\ layout \in [Workspaces -> {"floating", "tiled"}]
    /\ loaded \in BOOLEAN

\* The mode is the truth: every window on a workspace floats exactly when the workspace floats or
\* it floats by its own nature there. The exceptions are the user's toggle since the mode last reached
\* the window, a full-screen window, and a minimized one (it takes the mode when it comes back).
ModeConsistent ==
    \A w \in OpenW : ws[w] # Special /\ ~fs[w] /\ ~toggled[w] =>
        floating[w] = (OwnTarget(grp, own, ws, w) \/ Floats(layout, loaded, ws[w]))

\* A group floats, tiles and goes full screen as one.
GroupCoherent ==
    \A v, w \in OpenW : grp[v] # NONE /\ grp[v] = grp[w] =>
        /\ floating[v] = floating[w] /\ fs[v] = fs[w] /\ toggled[v] = toggled[w]

\* A window that floats by its own nature where it is is never tiled but by the user.
OwnStaysFloating ==
    [][\A w \in Windows : (ws[w] # NONE /\ ws'[w] # NONE /\ OwnTarget(grp', own', ws', w) /\ floating[w] /\ ~floating'[w]) => toggled'[w]]_vars

=========================================================================

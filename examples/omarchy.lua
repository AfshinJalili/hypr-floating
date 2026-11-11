-- Omarchy's floating mode off, hypr-floating's layout on. Put these lines in
-- ~/.config/hypr/hyprland.lua after require("default.hypr.toggles"), and delete
-- ~/.local/state/omarchy/workspace-layouts/default.lua (the saved default "floating").
-- test/run-omarchy.sh runs this file against Omarchy's own Lua.

-- Every workspace floats, except those Omarchy saved another layout for (1.lua).
-- No Omarchy tags: Omarchy's Lua strips them from, and tiles, any window on a
-- workspace its own modes do not float.
hl.config({ general = { layout = "floating" }, plugin = { hypr_floating = { omarchy_tags = 0 } } })

-- Omarchy sets up the looks of floating workspaces (titlebars, shadows, opaque
-- windows) when one of its own workspaces floats. Give it one nobody uses ...
o.workspace_mode({ workspace = "99", mode = "floating" })
-- ... and point those looks at the windows of the layout's workspaces.
hl.config({ plugin = { hyprbars = { workspace_tag = "hypr-floating-workspace" } } })
o.window({ tag = "hypr-floating-workspace" }, { opacity = "1.0 override 1.0 override", no_shadow = false })

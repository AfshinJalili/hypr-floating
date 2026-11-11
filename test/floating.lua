-- Test bed for the floating layout in a nested Hyprland. Workspace 1 has the layout
-- "floating", workspace 2 stays dwindle. PLUGINS lists .so files, space-separated;
-- WS1_LAYOUT overrides the layout of workspace 1 (to run without the plugin, say).
hl.monitor({ output = "WAYLAND-1", mode = os.getenv("MODE") or "preferred", position = "auto", scale = "1" })
hl.config({
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, disable_watchdog_warning = true },
  input = { follow_mouse = 0 },
  general = { resize_on_border = true },
  animations = { enabled = false },
})
hl.workspace_rule({ workspace = "1", layout = os.getenv("WS1_LAYOUT") or "floating" })
-- Windows of class F float by a window rule of their own, as a dialog would.
hl.window_rule({ match = { class = "^F" }, float = true })
for path in (os.getenv("PLUGINS") or ""):gmatch("%S+") do
  hl.plugin.load(path)
end
-- OMARCHY_TAGS=0 turns the Omarchy compatibility tags off.
if os.getenv("OMARCHY_TAGS") == "0" then
  hl.config({ plugin = { hypr_floating = { omarchy_tags = 0 } } })
end
-- BARS=1: the titlebars plugin (loaded through PLUGINS) draws a bar on the windows of floating workspaces.
if os.getenv("BARS") == "1" and hl.plugin.hyprbars then
  hl.config({ plugin = { hyprbars = {
    enabled = true, workspace_tag = "omarchy-floating-workspace", bar_height = 30, bar_color = "rgb(ff8800)",
    bar_part_of_window = true, bar_precedence_over_border = true,
  } } })
end
-- Right and middle button drag and resize a window, so a test can do it with no key held.
hl.bind("mouse:273", hl.dsp.window.drag(), { mouse = true })
hl.bind("mouse:274", hl.dsp.window.resize(), { mouse = true })

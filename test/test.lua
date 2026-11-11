-- Test bed for a nested Hyprland. Every window floats but class T, as on an Omarchy
-- floating workspace; T is the tiled one. PLUGINS lists .so files, space-separated.
hl.monitor({ output = "WAYLAND-1", mode = os.getenv("MODE") or "preferred", position = "auto", scale = "1" })
hl.config({
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, disable_watchdog_warning = true },
  input = { follow_mouse = 0 },
  animations = { enabled = false },
})
hl.window_rule({ match = { class = "^[^T]" }, float = true })
for path in (os.getenv("PLUGINS") or ""):gmatch("%S+") do
  hl.plugin.load(path)
end

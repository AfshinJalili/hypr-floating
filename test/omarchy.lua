-- Test bed: Omarchy's own Lua (helpers, looks, window rules, saved workspace layouts) plus this
-- plugin, in a nested Hyprland. Nothing of Omarchy's autostart, bindings or services is loaded.
--   XDG_STATE_HOME  a directory with omarchy/workspace-layouts/*.lua, as Omarchy saves them
--   PLUGINS         .so files to load, space-separated
--   USER_LUA        a file run after Omarchy's modules: the user's own lines of hyprland.lua
for name in pairs(package.loaded) do
  if name == "hypr" or name:find("^hypr%.") or name:find("^default%.hypr") then
    package.loaded[name] = nil
  end
end
package.path = (os.getenv("XDG_STATE_HOME") or "") .. "/?.lua;" .. (os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/?.lua;" .. package.path

hl.monitor({ output = "WAYLAND-1", mode = "preferred", position = "auto", scale = "1" })
hl.config({
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, disable_watchdog_warning = true },
  animations = { enabled = false },
})

require("default.hypr.helpers")
require("default.hypr.looknfeel")
require("default.hypr.windows")
for path in (os.getenv("PLUGINS") or ""):gmatch("%S+") do
  pcall(hl.plugin.load, path)
end
require("default.hypr.workspace-layouts")
if os.getenv("USER_LUA") and os.getenv("USER_LUA") ~= "" then
  dofile(os.getenv("USER_LUA"))
end

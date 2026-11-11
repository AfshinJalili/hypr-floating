-- hypr-floating on Omarchy: Omarchy's floating workspace mode becomes the plugin's
-- `floating` layout. Omarchy's toggle (Super + L, the bar's layout button), its bar, its
-- default layout and the layouts it saves in ~/.local/state/omarchy/workspace-layouts/
-- keep working unchanged: they all go through o.workspace_mode, which this file replaces.
--
-- Load it from ~/.config/hypr/hyprland.lua after the plugin and BEFORE
-- require("default.hypr.toggles"), which loads the saved layouts through o.workspace_mode.
-- Omarchy's own floating mode then never acts on a workspace.

-- The tag the plugin puts on every window of a floating workspace.
local FLOATING_TAG = "hypr-floating-workspace"

-- Omarchy's workspace modes. Its setup of what floating workspaces look like (shadows,
-- opaque windows, its titlebar plugin in the theme's colours) is a local function the
-- original o.workspace_mode calls; reach it from there.
require("default.hypr.workspace-modes")

local function upvalue(fn, wanted)
  local i = 1
  while true do
    local name, value = debug.getupvalue(fn, i)
    if name == nil or name == wanted then
      return value
    end
    i = i + 1
  end
end

local omarchy_set_up_floating = upvalue(o.workspace_mode, "set_up_floating")
if not omarchy_set_up_floating then
  hl.notification.create({
    text = "hypr-floating: Omarchy's workspace-modes.lua has no set_up_floating; floating workspaces get no titlebars",
    duration = 15000,
    icon = "error",
  })
end

-- Once per config load, the first time something floats: Omarchy's setup, pointed at the
-- plugin's tag rather than Omarchy's own.
local looks_ready = false
local function set_up_floating()
  if looks_ready then
    return
  end
  looks_ready = true

  if omarchy_set_up_floating then
    omarchy_set_up_floating()
  end
  -- The titlebar plugin is only there from the config pass after Omarchy first loads it.
  if hl.plugin.hyprbars then
    hl.config({ plugin = { hyprbars = { workspace_tag = FLOATING_TAG } } })
  end
  o.window({ tag = FLOATING_TAG }, { opacity = "1.0 override 1.0 override", no_shadow = false })
end

-- On a floating workspace windows overlap, so focus follows clicks, not the pointer, as in
-- Omarchy's floating mode. Every other workspace keeps the user's own setting.
local follow_mouse = hl.get_config("input.follow_mouse")
local follows = nil

local function update_follow_mouse()
  local workspace = hl.get_active_workspace()
  local value = workspace ~= nil and workspace.tiled_layout == "floating" and 0 or follow_mouse
  if value ~= follows then
    follows = value
    hl.config({ input = { follow_mouse = value } })
  end
end

-- A layout set here applies once the call returns.
local function update_follow_mouse_later()
  hl.timer(update_follow_mouse, { type = "oneshot", timeout = 1 })
end

hl.on("workspace.active", update_follow_mouse)
hl.on("monitor.focused", update_follow_mouse)
update_follow_mouse_later()

-- A maximized window has a floating workspace to itself until another window opens there,
-- which brings it back to its own size so the two can share it, as in Omarchy's floating mode.
hl.on("window.open", function(window)
  local workspace = window.workspace
  if not workspace or workspace.tiled_layout ~= "floating" then
    return
  end
  for _, other in ipairs(hl.get_workspace_windows(tostring(workspace.id))) do
    if other.address ~= window.address and (other.fullscreen or 0) == 1 then
      hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = other }))
    end
  end
end)

-- { workspace = "N", mode = M } gives workspace N the layout M; { default = M } gives it to
-- every workspace without one of its own. "floating" is the plugin's layout.
function o.workspace_mode(spec)
  local mode = spec.default or spec.mode
  if spec.default then
    hl.config({ general = { layout = mode } })
  else
    hl.workspace_rule({ workspace = tostring(spec.workspace), layout = mode })
  end
  if mode == "floating" then
    set_up_floating()
  end
  update_follow_mouse_later()
end

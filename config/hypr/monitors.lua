-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all
-- Match by description so DP port names can change without flipping the layout.

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Physical layout: Ultra HD on the left, HDR 4K on the right.
hl.monitor({
  output = "desc:LG Electronics LG Ultra HD 0x000732A1",
  mode = "preferred",
  position = "0x0",
  scale = omarchy_monitor_scale,
})
hl.monitor({
  output = "desc:LG Electronics LG HDR 4K 108NTHMGT977",
  mode = "preferred",
  position = "auto-right",
  scale = omarchy_monitor_scale,
})

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

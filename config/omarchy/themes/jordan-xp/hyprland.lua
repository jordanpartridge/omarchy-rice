local active_border_color = { colors = { "rgba(0d5c5eff)", "rgba(3ec8b2ff)" }, angle = 180 }
local inactive_border_color = "rgba(1a3a4aaa)"

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
    border_size = 5,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
  decoration = {
    rounding = 0,
    shadow = {
      enabled = true,
      range = 8,
      render_power = 3,
      color = "rgba(00000066)",
      color_inactive = "rgba(00000033)",
    },
    blur = {
      enabled = false,
    },
  },
})

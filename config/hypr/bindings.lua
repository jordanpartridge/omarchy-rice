-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Super+Shift+A default is ChatGPT (chatgpt.com). Open Grok Build instead.
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "Grok Build", { tui = "grok", focus = true })

-- iMessage via BlueFerry (launch or focus the existing window).
o.bind("SUPER + SHIFT + I", "iMessage", { launch = "/home/jordan/.local/bin/blueferry-quickshell", focus = "BlueFerry" })

-- Pause/resume local models (Ollama stays up). Does not touch Grok.
o.bind("SUPER + SHIFT + CTRL + O", "Toggle local AI", "/home/jordan/.local/bin/local-ai toggle")

-- GitHub org glance (jordanpartridge, the-shit, conduit-ui, synapse-sentinel).
o.bind("SUPER + SHIFT + G", "GitHub orgs", "omarchy-shell shell toggle jordan.github-orgs")

-- Omarchy root menu (Start cabinet is off). Super+Space is the same door.
hl.unbind("SUPER + CTRL + J")
o.bind("SUPER + CTRL + J", "Omarchy menu", "omarchy-menu toggle root")

-- Jordan OS floating clock gadget.
o.bind("SUPER + CTRL + U", "Jordan OS clock", "omarchy-shell shell toggle jordan.os-clock")

-- Super+M opens the Music cabinet (start / stop / search / playlists).
-- Release so Super is not still down when typing into Search.
-- SUPER+SHIFT+M stays Music TUI; SUPER+SHIFT+ALT+M stays Music TUI (premium).
hl.unbind("SUPER + M")
o.bind("SUPER + M", "Music", "omarchy menu summon music", { release = true })

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

#!/usr/bin/env bash
# Compile Jordan OS theme files from options.json, then apply layout + chrome.
set -euo pipefail

THEME_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OPTIONS_FILE="$THEME_DIR/options.json"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
CURRENT_NAME_FILE="$STATE_DIR/current/theme.name"
CURRENT_THEME_DIR="$STATE_DIR/current/theme"
WRITE_ONLY=0
DO_APPLY=1
DO_THEME_SET=0

usage() {
  cat <<'EOF'
Jordan OS — cabinet + era desktops.

  jordan-os                     Show current options
  jordan-os status
  jordan-os era mac|95|xp|dos
  jordan-os room bliss|dirt|gold|night|soundtrack
  jordan-os dont_paint on|off
  jordan-os gaps tight|classic|room
  jordan-os shadows on|off
  jordan-os bar top|bottom|left|right
  jordan-os layout              Apply bar + wallpaper from options
  jordan-os apply               Rewrite files and omarchy theme set jordan-os
  jordan-os --write-only        Rewrite files without applying

Display Properties lives on the Start button (left of the bar)
or Super+Ctrl+J. Cycle wallpapers with: omarchy theme bg next
Unlock copy: Biker, not cyclist
EOF
}

need_python() {
  command -v python3 >/dev/null 2>&1 || {
    echo "python3 is required" >&2
    exit 1
  }
}

read_options() {
  need_python
  python3 - "$OPTIONS_FILE" <<'PY'
import json, sys
path = sys.argv[1]
default_layouts = {
    "mac": {"bar": "top", "gaps": "classic", "shadows": True},
    "95": {"bar": "bottom", "gaps": "tight", "shadows": False},
    "xp": {"bar": "bottom", "gaps": "classic", "shadows": True},
    "dos": {"bar": "left", "gaps": "tight", "shadows": False},
}
defaults = {
    "era": "xp",
    "room": "bliss",
    "dont_paint": False,
    "gaps": "classic",
    "shadows": True,
    "layouts": default_layouts,
}
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
if not isinstance(data, dict):
    data = {}
era = str(data.get("era") or defaults["era"])
if era not in default_layouts:
    era = "xp"
layouts = dict(default_layouts)
raw_layouts = data.get("layouts") if isinstance(data.get("layouts"), dict) else {}
for key, fallback in default_layouts.items():
    src = raw_layouts.get(key) if isinstance(raw_layouts.get(key), dict) else {}
    layouts[key] = {
        "bar": src.get("bar", fallback["bar"]),
        "gaps": src.get("gaps", fallback["gaps"]),
        "shadows": src.get("shadows", fallback["shadows"]),
    }
era_layout = layouts[era]
gaps = data.get("gaps", era_layout["gaps"])
shadows = data.get("shadows", era_layout["shadows"])
if shadows in (True, "true", "on", 1, "1"):
    shadows_on = True
else:
    shadows_on = False
dont = data.get("dont_paint", False)
dont_on = dont in (True, "true", "on", 1, "1")
room = str(data.get("room") or defaults["room"])
bar = str(era_layout.get("bar") or "bottom")
print("ERA=" + era)
print("ROOM=" + room)
print("DONT_PAINT=" + ("1" if dont_on else "0"))
print("GAPS=" + str(gaps))
print("SHADOWS=" + ("1" if shadows_on else "0"))
print("BAR=" + bar)
print("MAC_BAR=" + str(layouts["mac"]["bar"]))
print("WIN95_BAR=" + str(layouts["95"]["bar"]))
print("XP_BAR=" + str(layouts["xp"]["bar"]))
print("DOS_BAR=" + str(layouts["dos"]["bar"]))
PY
}

write_option() {
  local key="$1"
  local value="$2"
  need_python
  python3 - "$OPTIONS_FILE" "$key" "$value" <<'PY'
import json, sys
path, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
default_layouts = {
    "mac": {"bar": "top", "gaps": "classic", "shadows": True},
    "95": {"bar": "bottom", "gaps": "tight", "shadows": False},
    "xp": {"bar": "bottom", "gaps": "classic", "shadows": True},
    "dos": {"bar": "left", "gaps": "tight", "shadows": False},
}
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
if not isinstance(data, dict):
    data = {}
layouts = dict(default_layouts)
raw = data.get("layouts") if isinstance(data.get("layouts"), dict) else {}
for era_key, fallback in default_layouts.items():
    src = raw.get(era_key) if isinstance(raw.get(era_key), dict) else {}
    layouts[era_key] = {
        "bar": src.get("bar", fallback["bar"]),
        "gaps": src.get("gaps", fallback["gaps"]),
        "shadows": src.get("shadows", fallback["shadows"]),
    }
era = str(data.get("era") or "xp")
if era not in layouts:
    era = "xp"

if key == "era":
    if value not in layouts:
        raise SystemExit("era: mac|95|xp|dos")
    era = value
    data["era"] = era
    data["gaps"] = layouts[era]["gaps"]
    data["shadows"] = layouts[era]["shadows"]
elif key == "dont_paint":
    data[key] = value in ("on", "true", "1")
elif key == "shadows":
    on = value in ("on", "true", "1")
    data["shadows"] = on
    layouts[era]["shadows"] = on
elif key == "gaps":
    data["gaps"] = value
    layouts[era]["gaps"] = value
elif key == "bar":
    layouts[era]["bar"] = value
elif key == "room":
    data["room"] = value
else:
    data[key] = value

data["layouts"] = layouts
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

print_status() {
  eval "$(read_options)"
  cat <<EOF
Jordan OS
  era         $ERA          (mac | 95 | xp | dos)
  room        $ROOM         (bliss | dirt | gold | night | soundtrack)
  dont_paint  $([[ $DONT_PAINT == 1 ]] && echo on || echo off)
  gaps        $GAPS         (tight | classic | room)
  shadows     $([[ $SHADOWS == 1 ]] && echo on || echo off)
  bar         $BAR          (per-era remembered)
EOF
}

room_wallpaper() {
  local room="$1"
  local era="$2"
  if [[ $era == dos ]]; then
    echo "$THEME_DIR/backgrounds/dos-norton.png"
    return
  fi
  case "$room" in
    dirt) echo "$THEME_DIR/backgrounds/2-new-austin.jpg" ;;
    gold) echo "$THEME_DIR/backgrounds/1-erdtree-hills.jpg" ;;
    night) echo "$THEME_DIR/backgrounds/4-mesa-dusk.jpg" ;;
    soundtrack) echo "$THEME_DIR/backgrounds/3-asgard-hills.jpg" ;;
    bliss|*) echo "$THEME_DIR/backgrounds/0-bliss-mesa.jpg" ;;
  esac
}

write_theme_files() {
  eval "$(read_options)"

  local accent selection muted
  local background dark_background darker_background lighter_background
  local foreground dark_foreground light_foreground bright_foreground
  local red yellow orange green cyan blue magenta brown
  local bright_red bright_yellow bright_green bright_cyan bright_blue bright_magenta
  local bar_bg bar_text bar_active
  local popup_bg popup_text popup_border
  local selected_bg selected_text
  local active_border_a active_border_b inactive_border
  local icons_theme start_a start_b keyboard
  local gaps_in gaps_out border_size rounding
  local shadow_enabled shadow_range
  local menu_bg menu_text
  local paper ink muted_ink select_bg select_fg header_bg
  local start_shape

  # Dark table + AAA body text. Era paints chrome, not beige paper.
  paper="#0A0C10"
  ink="#F4F1E4"
  muted_ink="#A8B4A8"
  select_fg="#FFFEF8"
  header_bg=""
  rounding=0
  start_shape="pill"

  case "$ERA" in
    mac)
      # Aqua: candy stripe, traffic-light border, top menu bar.
      accent="#5AC8FA"; selection="#0A3A6A"; muted="#7AA0C0"
      background="#0A1420"; dark_background="#070E16"; darker_background="#04080C"
      lighter_background="#162436"
      foreground="#F2F7FC"; dark_foreground="#7AA0C0"; light_foreground="#D8E6F4"
      bright_foreground="#FFFEF8"
      red="#FF5F57"; yellow="#FEBC2E"; orange="#F5A623"; green="#28C840"
      cyan="#5AC8FA"; blue="#007AFF"; magenta="#AF52DE"; brown="#8A6A40"
      bright_red="#FF8A84"; bright_yellow="#FFE08A"; bright_green="#5EE06A"
      bright_cyan="#88D8FF"; bright_blue="#4AA8FF"; bright_magenta="#C88AEE"
      bar_bg="#3A7BD4"; bar_text="#FFFEF8"; bar_active="#FEBC2E"
      header_bg="#4A8AE0"; select_bg="#0A3A6A"
      active_border_a="rgba(ff5f57ff)"; active_border_b="rgba(28c840ff)"; inactive_border="rgba(3a5a80aa)"
      icons_theme="Yaru-blue"; keyboard="5AC8FA"
      start_a="#4A8AE0"; start_b="#6AA8F0"
      rounding=8
      start_shape="aqua"
      popup_border="#5AC8FA"
      ;;
    95)
      # Chicago gray, 3D bevel, square Start, bottom bar.
      accent="#C0C0C0"; selection="#000080"; muted="#8A8A8A"
      background="#101214"; dark_background="#0A0C0E"; darker_background="#050606"
      lighter_background="#1C1E22"
      foreground="#F4F4F4"; dark_foreground="#8A8A8A"; light_foreground="#E0E0E0"
      bright_foreground="#FFFFFF"
      red="#C04040"; yellow="#C0A030"; orange="#C07030"; green="#40A040"
      cyan="#4080A0"; blue="#000080"; magenta="#804080"; brown="#6A4A20"
      bright_red="#E06060"; bright_yellow="#E0C050"; bright_green="#60C060"
      bright_cyan="#60A0C0"; bright_blue="#4040C0"; bright_magenta="#A060A0"
      bar_bg="#C0C0C0"; bar_text="#000000"; bar_active="#000080"
      header_bg="#000080"; select_bg="#000080"; select_fg="#FFFFFF"
      ink="#F4F4F4"; muted_ink="#B0B0B0"
      active_border_a="rgba(ffffffee)"; active_border_b="rgba(404040ff)"; inactive_border="rgba(808080aa)"
      icons_theme="Yaru"; keyboard="C0C0C0"
      start_a="#C0C0C0"; start_b="#A0A0A0"
      rounding=0
      start_shape="square"
      popup_border="#FFFFFF"
      ;;
    dos)
      # Norton/MC: phosphor on navy, no landscape.
      accent="#55FFFF"; selection="#0000AA"; muted="#55AA55"
      background="#000055"; dark_background="#000040"; darker_background="#000028"
      lighter_background="#000070"
      foreground="#55FF55"; dark_foreground="#00AA00"; light_foreground="#AAFFAA"
      bright_foreground="#FFFFFF"
      red="#FF5555"; yellow="#FFFF55"; orange="#FFAA00"; green="#55FF55"
      cyan="#55FFFF"; blue="#5555FF"; magenta="#FF55FF"; brown="#AA5500"
      bright_red="#FF8888"; bright_yellow="#FFFF88"; bright_green="#88FF88"
      bright_cyan="#88FFFF"; bright_blue="#8888FF"; bright_magenta="#FF88FF"
      bar_bg="#0000AA"; bar_text="#FFFF55"; bar_active="#55FF55"
      header_bg="#0000AA"; select_bg="#0000AA"; select_fg="#FFFF55"
      ink="#55FF55"; muted_ink="#00AA00"; paper="#000028"
      active_border_a="rgba(55ffffff)"; active_border_b="rgba(55ff55ff)"; inactive_border="rgba(0000aaaa)"
      icons_theme="Yaru"; keyboard="55FF55"
      start_a="#0000AA"; start_b="#0000CC"
      rounding=0
      start_shape="dos"
      popup_border="#55FF55"
      ;;
    xp|*)
      # XP-frame, dark table, Bliss treatment. Not beige paper.
      accent="#3EC8B2"; selection="#0D5C5E"; muted="#9AA6A0"
      background="#0B1418"; dark_background="#070E12"; darker_background="#04080A"
      lighter_background="#162228"
      foreground="#F4F1E4"; dark_foreground="#9AA6A0"; light_foreground="#E8E4D4"
      bright_foreground="#FFFEF8"
      red="#E07050"; yellow="#E8C547"; orange="#E08A40"; green="#3EC8B2"
      cyan="#5AB8C8"; blue="#4A90C8"; magenta="#C080B0"; brown="#8A5A20"
      bright_red="#FF8A6A"; bright_yellow="#F4D878"; bright_green="#5EE0CC"
      bright_cyan="#7AD0E0"; bright_blue="#6AA8E0"; bright_magenta="#D8A0C8"
      bar_bg="#12324A"; bar_text="#FFFEF8"; bar_active="#3EC8B2"
      header_bg="#16485A"; select_bg="#0D5C5E"
      active_border_a="rgba(0d5c5eff)"; active_border_b="rgba(3ec8b2ff)"; inactive_border="rgba(1a3a4aaa)"
      icons_theme="Yaru-prussiangreen"; keyboard="3EC8B2"
      start_a="#0A5C4A"; start_b="#0D6B4A"
      rounding=0
      start_shape="pill"
      popup_border="#39FF14"
      ;;
  esac
  [[ -n $header_bg ]] || header_bg="$bar_bg"

  case "$GAPS" in
    tight) gaps_in=0; gaps_out=0 ;;
    room)  gaps_in=6; gaps_out=12 ;;
    classic|*) gaps_in=2; gaps_out=4 ;;
  esac

  case "$ERA" in
    mac) border_size=3 ;;
    95) border_size=4 ;;
    dos) border_size=1 ;;
    xp|*) border_size=5 ;;
  esac

  if [[ $SHADOWS == 1 ]]; then
    shadow_enabled="true"
    shadow_range=8
  else
    shadow_enabled="false"
    shadow_range=0
  fi

  popup_bg="#070B08"
  popup_text="#E8F0E8"
  selected_bg="$selection"
  selected_text="$bright_foreground"
  menu_bg="#070B08"
  menu_text="#E8F0E8"

  case "$ERA" in
    dos)
      popup_bg="#000028"
      popup_text="#55FF55"
      selected_bg="#0000AA"
      selected_text="#FFFF55"
      menu_bg="#000028"
      menu_text="#55FF55"
      ;;
    95)
      popup_bg="#101214"
      popup_text="#F4F4F4"
      selected_bg="#000080"
      selected_text="#FFFFFF"
      menu_bg="#101214"
      menu_text="#F4F4F4"
      ;;
    mac)
      popup_bg="#0A1420"
      popup_text="#F2F7FC"
      selected_bg="#0A3A6A"
      selected_text="#FFFEF8"
      menu_bg="#0A1420"
      menu_text="#F2F7FC"
      ;;
    xp|*)
      popup_bg="#000000"
      popup_text="#D2FFD8"
      popup_border="#39FF14"
      selected_bg="#0A3D28"
      selected_text="#E8FFE9"
      menu_bg="#000000"
      menu_text="#D2FFD8"
      ;;
  esac

  hex_to_rgb() {
    local hex="${1#\#}"
    printf "%d,%d,%d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
  }

  cat >"$THEME_DIR/colors.toml" <<EOF
mode = "dark"

accent = "$accent"
selection = "$selection"
muted = "$muted"

background = "$background"
dark_background = "$dark_background"
darker_background = "$darker_background"
lighter_background = "$lighter_background"

foreground = "$foreground"
dark_foreground = "$dark_foreground"
light_foreground = "$light_foreground"
bright_foreground = "$bright_foreground"

red = "$red"
yellow = "$yellow"
orange = "$orange"
green = "$green"
cyan = "$cyan"
blue = "$blue"
magenta = "$magenta"
brown = "$brown"

bright_red = "$bright_red"
bright_yellow = "$bright_yellow"
bright_green = "$bright_green"
bright_cyan = "$bright_cyan"
bright_blue = "$bright_blue"
bright_magenta = "$bright_magenta"

hyprland_active_border = "$active_border_a $active_border_b 180deg"
hyprland_inactive_border = "$inactive_border"
EOF

  cat >"$THEME_DIR/hyprland.lua" <<EOF
local active_border_color = { colors = { "$active_border_a", "$active_border_b" }, angle = 180 }
local inactive_border_color = "$inactive_border"

hl.config({
  general = {
    gaps_in = $gaps_in,
    gaps_out = $gaps_out,
    border_size = $border_size,
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
    rounding = $rounding,
    shadow = {
      enabled = $shadow_enabled,
      range = $shadow_range,
      render_power = 3,
      color = "rgba(00000066)",
      color_inactive = "rgba(00000033)",
    },
    blur = {
      enabled = false,
    },
  },
})
EOF

  printf '%s\n' "$icons_theme" >"$THEME_DIR/icons.theme"
  printf '%s\n' "$keyboard" >"$THEME_DIR/keyboard.rgb"
  printf '%s\n' "$(hex_to_rgb "$background")" >"$THEME_DIR/chromium.theme"

  cat >"$THEME_DIR/shell.bar.toml" <<EOF
[bar]
background       = "$bar_bg"
background-alpha = 1.0
text             = "$bar_text"
active           = "$bar_active"
scale-with-font  = true
size-horizontal  = 30
size-vertical    = 32
EOF

  cat >"$THEME_DIR/shell.popups.toml" <<EOF
[popups]
background       = "$popup_bg"
background-alpha = 1.0
text             = "$popup_text"
border           = "$popup_border"
border-alpha     = 1.0
border-width     = 2
EOF

  cat >"$THEME_DIR/shell.menu.toml" <<EOF
[menu]
background                = "$menu_bg"
background-alpha          = 1.0
text                      = "$menu_text"
border                    = "$popup_border"
border-alpha              = 1.0
scrim                     = "$background"
scrim-alpha               = 0.45
selected-background       = "$selected_bg"
selected-background-alpha = 1.0
selected-text             = "$selected_text"
selected-border           = "$popup_border"
selected-border-alpha     = 0.0
EOF

  cat >"$THEME_DIR/shell.launcher.toml" <<EOF
[launcher]
background                = "$menu_bg"
background-alpha          = 1.0
text                      = "$menu_text"
border                    = "$popup_border"
border-alpha              = 1.0
scrim                     = "$background"
scrim-alpha               = 0.45
selected-background       = "$selected_bg"
selected-background-alpha = 1.0
selected-text             = "$selected_text"
selected-border           = "$popup_border"
selected-border-alpha     = 0.0
EOF

  cat >"$THEME_DIR/shell.notifications.toml" <<EOF
[notifications]
background       = "$popup_bg"
background-alpha = 1.0
text             = "$popup_text"
border           = "$popup_border"
border-alpha     = 1.0
countdown        = "$popup_border"
EOF

  cat >"$THEME_DIR/shell.tooltip.toml" <<EOF
[tooltip]
background       = "$popup_bg"
background-alpha = 0.97
text             = "$popup_text"
border           = "$popup_border"
border-alpha     = 1.0
EOF

  cat >"$THEME_DIR/shell.lock.toml" <<EOF
[lock]
background       = "$popup_bg"
background-alpha = 0.92
text             = "$popup_text"
placeholder      = "$muted"
text-error       = "$red"
border           = "hyprland.active-border"
border-active    = "hyprland.active-border"
border-error     = "$red"
border-alpha     = 1.0
selection        = "$accent"
selection-alpha  = 0.45
EOF

  cat >"$THEME_DIR/shell.controls.toml" <<EOF
[controls]
normal-color        = "$popup_text"
normal-fill-alpha   = 0.04
normal-border       = "$popup_text"
normal-border-width = 1
normal-border-alpha = 0.35
hover-cursor-color        = "$popup_text"
hover-cursor-fill-alpha   = 0.10
hover-cursor-border       = "$popup_border"
hover-cursor-border-width = 1
hover-cursor-border-alpha = 0.85
focus-color        = "$popup_text"
focus-fill-alpha   = 0.10
focus-border       = "$popup_border"
focus-border-width = 1
focus-border-alpha = 0.55
selected-color        = "$selected_text"
selected-fill-alpha   = 1.0
selected-border       = "$selected_bg"
selected-border-width = 0
selected-border-alpha = 1.0
pressed-fill-alpha   = 0.22
selection-fill-alpha = 1.0
EOF

  cat >"$THEME_DIR/start.json" <<EOF
{
  "from": "$start_a",
  "to": "$start_b",
  "bar": "$bar_bg",
  "bar_text": "$bar_text",
  "header": "$header_bg",
  "footer": "$bar_bg",
  "ink": "$ink",
  "muted": "$muted_ink",
  "select": "$select_bg",
  "select_text": "$select_fg",
  "paper": "$paper",
  "era": "$ERA",
  "room": "$ROOM",
  "shape": "$start_shape",
  "chrome": "xp"
}
EOF
}

patch_current_shell_toml() {
  local dest="$1"
  python3 - "$dest" "$THEME_DIR" <<'PY'
import pathlib, re, sys
dest = pathlib.Path(sys.argv[1])
theme = pathlib.Path(sys.argv[2])
if not dest.is_file():
    sys.exit(0)
text = dest.read_text()
for path in sorted(theme.glob("shell.*.toml")):
    if path.name == "shell.toml":
        continue
    section = path.name[len("shell."):-len(".toml")]
    body = path.read_text()
    # Keep the [section] header from the override file.
    pattern = re.compile(r"(?ms)^\[%s\][^\[]*" % re.escape(section))
    if pattern.search(text):
        replacement = body if body.endswith("\n") else body + "\n"
        text = pattern.sub(lambda _m, r=replacement: r, text, count=1)
    else:
        text = text.rstrip() + "\n" + body
dest.write_text(text)
PY
}

sync_current_theme() {
  local current=""
  if [[ -f $CURRENT_NAME_FILE ]]; then
    current=$(<"$CURRENT_NAME_FILE")
  fi
  [[ $current == "jordan-os" ]] || return 0
  mkdir -p "$CURRENT_THEME_DIR"
  cp "$THEME_DIR/hyprland.lua" "$CURRENT_THEME_DIR/"
  cp "$THEME_DIR/colors.toml" "$CURRENT_THEME_DIR/"
  cp "$THEME_DIR/start.json" "$CURRENT_THEME_DIR/"
  cp "$THEME_DIR/icons.theme" "$CURRENT_THEME_DIR/" 2>/dev/null || true
  cp "$THEME_DIR/keyboard.rgb" "$CURRENT_THEME_DIR/" 2>/dev/null || true
  cp "$THEME_DIR/chromium.theme" "$CURRENT_THEME_DIR/" 2>/dev/null || true
  cp "$THEME_DIR"/shell.*.toml "$CURRENT_THEME_DIR/" 2>/dev/null || true
  if [[ -f $CURRENT_THEME_DIR/shell.toml ]]; then
    patch_current_shell_toml "$CURRENT_THEME_DIR/shell.toml"
  fi
  hyprctl reload >/dev/null 2>&1 || true
  if command -v omarchy-shell >/dev/null 2>&1; then
    local colors_payload="" shell_payload=""
    if [[ -f $CURRENT_THEME_DIR/colors.toml ]]; then
      colors_payload=$(base64 -w 0 "$CURRENT_THEME_DIR/colors.toml")
    fi
    if [[ -f $CURRENT_THEME_DIR/shell.toml ]]; then
      shell_payload=$(base64 -w 0 "$CURRENT_THEME_DIR/shell.toml")
    fi
    timeout 2 omarchy-shell shell applyTheme "$colors_payload" "$shell_payload" >/dev/null 2>&1 || true
  fi
}

apply_bar_position() {
  eval "$(read_options)"
  omarchy bar position "$BAR" >/dev/null 2>&1 || true
}

apply_wallpaper() {
  eval "$(read_options)"
  if [[ $DONT_PAINT == 1 ]]; then
    return 0
  fi
  local bg
  bg=$(room_wallpaper "$ROOM" "$ERA")
  if [[ -f $bg ]]; then
    omarchy theme bg set "$bg" >/dev/null 2>&1 || true
  fi
}

apply_layout() {
  mkdir -p "$STATE_DIR/jordan-os"
  apply_bar_position
  apply_wallpaper
}

apply_live() {
  mkdir -p "$STATE_DIR/jordan-os"
  write_theme_files
  if [[ $WRITE_ONLY == 1 ]]; then
    return 0
  fi
  sync_current_theme
  apply_layout
}

apply_theme() {
  write_theme_files
  if [[ $DO_APPLY == 1 && $WRITE_ONLY == 0 ]]; then
    omarchy theme set jordan-os
  fi
}

ARGS=()
for arg in "$@"; do
  case "$arg" in
    --write-only) WRITE_ONLY=1; DO_APPLY=0 ;;
    --help|-h) usage; exit 0 ;;
    *) ARGS+=("$arg") ;;
  esac
done

set -- "${ARGS[@]+"${ARGS[@]}"}"

if [[ $# -eq 0 ]]; then
  print_status
  exit 0
fi

case "$1" in
  status) print_status ;;
  apply) apply_theme ;;
  layout)
    write_theme_files
    apply_live
    ;;
  era)
    [[ ${2:-} =~ ^(mac|95|xp|dos)$ ]] || { echo "era: mac|95|xp|dos" >&2; exit 1; }
    write_option era "$2"
    apply_live
    ;;
  room)
    [[ ${2:-} =~ ^(bliss|dirt|gold|night|soundtrack)$ ]] || { echo "room: bliss|dirt|gold|night|soundtrack" >&2; exit 1; }
    write_option room "$2"
    apply_live
    ;;
  dont_paint)
    [[ ${2:-} =~ ^(on|off)$ ]] || { echo "dont_paint: on|off" >&2; exit 1; }
    write_option dont_paint "$2"
    apply_live
    ;;
  gaps)
    [[ ${2:-} =~ ^(tight|classic|room)$ ]] || { echo "gaps: tight|classic|room" >&2; exit 1; }
    write_option gaps "$2"
    apply_live
    ;;
  shadows)
    [[ ${2:-} =~ ^(on|off)$ ]] || { echo "shadows: on|off" >&2; exit 1; }
    write_option shadows "$2"
    apply_live
    ;;
  bar)
    [[ ${2:-} =~ ^(top|bottom|left|right)$ ]] || { echo "bar: top|bottom|left|right" >&2; exit 1; }
    write_option bar "$2"
    apply_live
    ;;
  *)
    usage
    exit 1
    ;;
esac

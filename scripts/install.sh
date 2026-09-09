#!/usr/bin/env bash
# Overlay this rice onto ~/.config. Does not run `omarchy theme set`.
# Usage: scripts/install.sh [--thor]
#   --thor  also copy monitors.lua (dual LG layout on Thor)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THOR=0
for arg in "$@"; do
  case "$arg" in
    --thor) THOR=1 ;;
    -h|--help)
      sed -n '2,5p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

mkdir -p "$HOME/.config/omarchy" "$HOME/.config/hypr" \
  "$HOME/.config/alacritty" "$HOME/.config/ghostty" \
  "$HOME/.config/foot" "$HOME/.config/kitty"

rsync -a "$ROOT/config/omarchy/" "$HOME/.config/omarchy/"

if (( THOR )); then
  rsync -a "$ROOT/config/hypr/" "$HOME/.config/hypr/"
else
  rsync -a --exclude 'monitors.lua' "$ROOT/config/hypr/" "$HOME/.config/hypr/"
  echo "skipped hypr/monitors.lua (pass --thor for the dual LG layout)"
fi

cp "$ROOT/config/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
cp "$ROOT/config/ghostty/config" "$HOME/.config/ghostty/config"
cp "$ROOT/config/foot/foot.ini" "$HOME/.config/foot/foot.ini"
cp "$ROOT/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

if (( THOR )) && [[ -d "$ROOT/streamdeck-plus" ]]; then
  mkdir -p "$HOME/.local/share/omarchy-streamdeck-demo/icons" \
    "$HOME/.local/bin" \
    "$HOME/.config/systemd/user"
  rsync -a --exclude '.gitignore' --exclude 'README.md' --exclude '*.service' \
    --exclude 'bin/' \
    "$ROOT/streamdeck-plus/" "$HOME/.local/share/omarchy-streamdeck-demo/"
  install -m 0755 "$ROOT/streamdeck-plus/bin/streamdeck-plus" "$HOME/.local/bin/streamdeck-plus"
  install -m 0644 "$ROOT/streamdeck-plus/streamdeck-plus.service" \
    "$HOME/.config/systemd/user/streamdeck-plus.service"
  systemctl --user daemon-reload
  systemctl --user enable --now streamdeck-plus.service >/dev/null 2>&1 || true
  echo "streamdeck-plus unit enabled (waits if the Plus is unplugged)"
fi

cat <<'EOF'
installed into ~/.config

next:
  omarchy plugin clone https://github.com/erikwb/omarchy-blueferry.git   # optional iMessage
  omarchy theme set jordan-os
  omarchy restart shell
  hyprctl reload
EOF

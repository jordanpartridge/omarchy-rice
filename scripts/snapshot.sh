#!/usr/bin/env bash
# Copy live ~/.config overlays into this repo. Run on Thor after a rice change.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RSYNC=(rsync -a --delete)

"${RSYNC[@]}" \
  --exclude '.git/' \
  --exclude '**/.git/' \
  --exclude '*.bak*' \
  --exclude '*.sample' \
  --exclude 'themes/aether/' \
  --exclude 'plugins/io.weirdware.blueferry/' \
  --exclude 'branding/screensaver-webcam.png' \
  "$HOME/.config/omarchy/" "$ROOT/config/omarchy/"

"${RSYNC[@]}" \
  --exclude '*.bak*' \
  "$HOME/.config/hypr/" "$ROOT/config/hypr/"

mkdir -p "$ROOT/config/"{alacritty,ghostty,foot,kitty}
cp "$HOME/.config/alacritty/alacritty.toml" "$ROOT/config/alacritty/alacritty.toml"
cp "$HOME/.config/ghostty/config" "$ROOT/config/ghostty/config"
cp "$HOME/.config/foot/foot.ini" "$ROOT/config/foot/foot.ini"
cp "$HOME/.config/kitty/kitty.conf" "$ROOT/config/kitty/kitty.conf"

LIVE_DECK="$HOME/.local/share/omarchy-streamdeck-demo"
if [[ -d "$LIVE_DECK" ]]; then
  mkdir -p "$ROOT/streamdeck-plus/icons"
  rsync -a \
    --exclude '__pycache__/' \
    --exclude 'faces/' \
    --exclude 'icons/tinted/' \
    --exclude 'serve.log' \
    --exclude 'serve.pid' \
    --exclude 'inbox.jsonl' \
    --exclude 'jobs/' \
    --exclude '*.pyc' \
    "$LIVE_DECK/demo.py" "$LIVE_DECK/actions.py" "$ROOT/streamdeck-plus/"
  if compgen -G "$LIVE_DECK/icons/*.jpg" >/dev/null; then
    rsync -a "$LIVE_DECK/icons/"*.jpg "$ROOT/streamdeck-plus/icons/"
  fi
  if [[ -f "$HOME/.config/systemd/user/streamdeck-plus.service" ]]; then
    # Keep %h in git; live unit may still say /home/jordan from before the overlay.
    :
  fi
  echo "snapshot: streamdeck-plus"
fi

echo "snapshot: $ROOT/config"

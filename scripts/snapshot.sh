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

echo "snapshot: $ROOT/config"

#!/bin/bash
# Restyle Stream Deck Plus occupancy faces after Omarchy theme-set.
# Complementary chrome — not a second catalog. Fail soft if hidraw is busy.
THEME_SLUG=${1:-}
DEMO_PY="${HOME}/.local/share/omarchy-streamdeck-demo/demo.py"

[[ -n $THEME_SLUG ]] || exit 0
[[ -f $DEMO_PY ]] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
command -v magick >/dev/null 2>&1 || exit 0

timeout -k 2 25 python3 "$DEMO_PY" --theme-set "$THEME_SLUG" >/dev/null 2>&1 || true
exit 0

#!/bin/bash
# Start the Stream Deck Plus dispatcher after the desktop is up.
# Complementary chrome — not a second catalog. Fail soft.
systemctl --user start streamdeck-plus.service >/dev/null 2>&1 || true
exit 0

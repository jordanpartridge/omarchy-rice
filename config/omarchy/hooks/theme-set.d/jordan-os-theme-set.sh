#!/bin/bash
# Jordan OS paint only. Start cabinet stays off — Omarchy menu is the door.
# Do not clobber streamdeck-*.sh hooks.
if [[ ${1:-} == "jordan-os" ]]; then
  omarchy plugin disable jordan.os >/dev/null 2>&1 || true
  omarchy plugin disable jordan.xp >/dev/null 2>&1 || true
  omarchy bar move omarchy.menu --section left --index 0 >/dev/null 2>&1 || true
  omarchy plugin enable jordan.os-clock >/dev/null 2>&1 || true
  omarchy plugin enable jordan.os-45 >/dev/null 2>&1 || true
  omarchy plugin disable jordan.xp-clock >/dev/null 2>&1 || true
  "$HOME/.config/omarchy/themes/jordan-os/apply.sh" layout >/dev/null 2>&1 || true
  omarchy-shell -q jordan.os-clock snap
  omarchy-shell -q jordan.os-45 snap
fi

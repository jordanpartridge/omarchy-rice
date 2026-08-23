#!/bin/bash
# Jordan XP paint only. Start cabinet stays off — Omarchy menu is the door.
if [[ ${1:-} == "jordan-xp" ]]; then
  omarchy plugin disable jordan.xp >/dev/null 2>&1 || true
  omarchy plugin disable jordan.os >/dev/null 2>&1 || true
  omarchy bar move omarchy.menu --section left --index 0 >/dev/null 2>&1 || true
fi

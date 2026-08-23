#!/bin/bash
# Restore Jordan OS floating gadgets after login. Fail soft.
omarchy-shell -q jordan.os-clock snap
omarchy-shell -q jordan.os-45 snap
exit 0

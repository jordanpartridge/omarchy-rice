# Stream Deck Plus

HID dispatcher for an Elgato Stream Deck Plus on Omarchy. Complementary chrome, not a second catalog.

Finds the deck by USB id `0fd9:0084`. Do not hardcode `/dev/hidrawN` — a keyboard often lands on `hidraw1`.

## Pages

Swipe the LCD strip or press **PAGE**. Order: MUSIC → DESK → SPACE → CREW. Hold the strip to lock.

| Page | Keys |
|---|---|
| MUSIC | moods, skip, play/pause toggle, like, mute, page |
| DESK | shot, rec, mute, nightlight, dnd, theme, next bg, page |
| SPACE | occupied workspace prev/next, browser, terminal, Herdr, page |
| CREW | SPEC / grok / local / night lamps, page |

Knobs: volume, mic, brightness, seek.

## Live path

```
~/.local/share/omarchy-streamdeck-demo/   # dispatcher (this tree, installed)
~/.config/systemd/user/streamdeck-plus.service
~/.local/bin/streamdeck-plus
```

`python3 demo.py --self-test` does not need the hardware.

`systemctl --user status streamdeck-plus.service` should stay `active` and log `on /dev/hidraw*` for the Plus, not a keyboard.

## Install

`scripts/install.sh --thor` in the rice repo copies this tree and enables the user unit.

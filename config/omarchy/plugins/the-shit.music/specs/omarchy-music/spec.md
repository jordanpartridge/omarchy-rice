# SPEC: Omarchy plugin for the-shit/music

Status: **DRAFT** — Jordan APPROVE before anyone types QML  
Repos: **new** `the-shit/omarchy-music` (plugin). Player stays `the-shit/music`.  
Slug: `omarchy-music`

**Story:** Omarchy is taking off. `music` is the soul of this org. The highlight is not a Rust rewrite of the CLI. It is a bar widget Omarchy people can install in one line, that talks to the `spotify` binary they already have — moods, skip, now-playing — instead of cloning stock `omarchy.media`.

The concept already exists on Thor: `~/.config/omarchy/themes/the-shit` (Spotify green, mesa, waveform). That theme is **not** v1 of this SPEC. The plugin is.

## Locked

- **Player = `the-shit/music`.** The plugin SHALL NOT call the Spotify Web API. SHALL NOT embed a second client. SHALL NOT rewrite the PHP CLI in Rust.
- **New public repo** `the-shit/omarchy-music` with `manifest.json` at the **repo root** so this works:

  ```bash
  omarchy plugin add https://github.com/the-shit/omarchy-music.git --enable
  ```

  Putting `manifest.json` at the root of `the-shit/music` (a Laravel Zero package) is forbidden.
- **Plugin id:** `the-shit.music` (the `omarchy.` namespace is reserved).
- **Kinds:** `service` + `bar-widget` (same shape as `omarchy.media`: one watcher, one chip).
- **Transport:** spawn the `spotify` binary on `PATH`.

  | UI action | argv |
  |---|---|
  | Refresh now-playing | `spotify current --json` |
  | Track-change stream (preferred) | `spotify watch --json --interval=3` |
  | Pause / resume / skip | `spotify pause --json` / `spotify play "<query>" --json` / `spotify skip --json` |

**Note:** The "play" action uses `play <query>` with the current track name instead of `resume` to ensure playback starts even when the device shows as active but isn't responding to playback commands.
  | Mood (v1, one-shot queue) | `spotify chill --json` / `spotify flow --json` / `spotify hype --json` |

  Do **not** start `spotify autopilot` from the widget. Autopilot is a long-running daemon, not a button.
- **Missing binary:** calm empty state. Do not crash the shell. Click MAY hint to `composer global require the-shit/music` + `spotify login`. Do not run composer or sudo.
- **Stock `omarchy.media` stays.** This plugin does not replace it. User may run both or disable the stock one.
- **No Rust in v1.** If Laravel Zero boot makes `current` too slow for a 3s poll, the *next* SPEC may add a thin `spotify pulse --json` fast path **in music**, or a watcher kept warm. Measure first. Do not invent a second player in Rust to dodge that.
- **Grok implements v1** (Quickshell on a live Omarchy box). Not `/local-worker`. Verify with `omarchy plugin validate` and a real bar, not a screenshot of QML.

## Files (plugin repo)

| Path | Job |
|---|---|
| `manifest.json` | schemaVersion 1, id `the-shit.music`, kinds service + bar-widget |
| `Service.qml` | Singleton: watch/poll `spotify`, expose now-playing + commands |
| `BarWidget.qml` | Chip: title · artist, play/pause glyph. Popup: skip, chill/flow/hype |
| `README.md` | Install line, requires `spotify` on PATH, not a player |
| `specs/omarchy-music/spec.md` | This contract, copied into the plugin repo |

## Acceptance

- [ ] `omarchy plugin validate .` exits 0 on the plugin folder
- [ ] `rg -n 'api.spotify.com|SPOTIFY_CLIENT' .` is empty in the plugin repo
- [ ] With `spotify` on PATH and something playing, the bar shows the same track as `spotify current --json`
- [ ] Skip / pause / resume from the popup change playback
- [ ] Chill / flow / hype from the popup invoke those binaries (queue fill), not autopilot
- [ ] With `spotify` missing from PATH, the shell stays up; widget is empty or a single glyph
- [ ] README install is exactly `omarchy plugin add https://github.com/the-shit/omarchy-music.git`

## Non-goals

- Rewriting `the-shit/music` in Rust (or anything else)
- Shipping `~/.config/omarchy/themes/the-shit` as this repo (theme pack is a later SPEC)
- Album-art wallpaper, Hyprland accent-from-cover, lyrics overlay
- MCP inside Quickshell
- Replacing `omarchy.media`
- Show HN / music `docs/launch.md`
- Night-shift / GPU typer for QML

## After APPROVE

1. Create public `the-shit/omarchy-music` (empty, this SPEC first).
2. Implement QML on a branch. Validate. PR. Jordan merges.
3. Only then: list at omarchyplugins.com if you still want the highlight.

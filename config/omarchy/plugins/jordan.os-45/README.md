# Jordan OS 45

Floating 45 gadget plus catalog Find overlay. Thor `~/.config/omarchy/` only.

| Door | Action |
|---|---|
| Click the 45 | Search overlay |
| Super+M | Music menu: Start, Stop, Search, Playlists |
| `omarchy menu summon music` | Same menu |
| `omarchy menu summon music.find` | Search overlay |
| Start → Music | Music menu |
| Music → Show 45 | Reopen the vinyl gadget |

Now-playing: `omarchy.media` / MPRIS when a player is active on this box, else `spotify current --json`, else empty sleeve. Skip uses MPRIS next when local, else `spotify skip`. Catalog search/play goes through `bin/catalog` (the-shit/music `searchMultiple`, 12 hits — same as `spotify find`). QML never talks to the Spotify Web API.

Wallpaper stays the room (Bliss until a track→room mapper exists). Album JPEG is the sleeve, not the desktop.

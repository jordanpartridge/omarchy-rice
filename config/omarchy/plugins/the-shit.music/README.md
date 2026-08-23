# the-shit/omarchy-music

Omarchy bar widget for [`the-shit/music`](https://github.com/the-shit/music). Not a Spotify client. It shells out to the `spotify` binary already on your `PATH`.

```bash
omarchy plugin add https://github.com/the-shit/omarchy-music.git
```

Then enable it (Setup › Plugins, or):

```bash
omarchy plugin enable the-shit.music --section right
```

Requires:

```bash
composer global require the-shit/music
spotify login
```

Stock `omarchy.media` stays. This does not replace it.

Mood buttons run `spotify chill` / `flow` / `hype` (one-shot queue fill). They do not start `spotify autopilot`.

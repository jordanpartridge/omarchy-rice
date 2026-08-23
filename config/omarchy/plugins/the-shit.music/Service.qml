import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool binaryPresent: false
  property bool probed: false
  property bool isPlaying: false
  property string title: ""
  property string artist: ""
  property string album: ""
  property string artUrl: ""
  property string uri: ""
  property string lastMood: ""
  property string hint: ""
  property bool actionBusy: false

  readonly property bool hasTrack: title !== ""
  readonly property string installHint: "composer global require the-shit/music && spotify login"

  function spotifyCmd(rest) {
    var parts = rest.split(" ")
    var cmd = ["spotify"]
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] !== "") cmd.push(parts[i])
    }
    return cmd
  }

  function applyCurrent(obj) {
    if (!obj) return
    var name = obj.name || obj.track || ""
    if (!name) {
      root.title = ""
      root.artist = ""
      root.album = ""
      root.artUrl = ""
      root.uri = ""
      root.isPlaying = false
      return
    }
    root.title = name
    root.artist = obj.artist || ""
    root.album = obj.album || ""
    root.artUrl = obj.album_art_url || obj.artUrl || ""
    root.uri = obj.uri || ""
    root.isPlaying = !!obj.is_playing
  }

  function applyWatch(obj) {
    if (!obj || !obj.type) return
    if (obj.type === "track_changed") {
      root.title = obj.track || ""
      root.artist = obj.artist || ""
      root.album = obj.album || ""
      root.uri = obj.uri || ""
      root.isPlaying = !!obj.is_playing
    } else if (obj.type === "playback_state_changed") {
      root.isPlaying = !!obj.is_playing
      if (obj.track) root.title = obj.track
    } else if (obj.type === "playback_stopped") {
      root.title = ""
      root.artist = ""
      root.album = ""
      root.artUrl = ""
      root.uri = ""
      root.isPlaying = false
    }
  }

  function refresh() {
    if (currentProc.running)
      currentProc.running = false
    currentProc.running = true
  }

  function runAction(rest) {
    if (actionProc.running) return
    root.actionBusy = true
    actionProc.command = spotifyCmd(rest)
    actionProc.running = true
  }

  function playPause() {
    if (!binaryPresent) return
    if (root.isPlaying) {
      runAction("pause --json")
    } else {
      // When not playing, use play with current track instead of resume
      // This ensures playback actually starts even if resume doesn't work
      // (e.g., when device shows as active but isn't responding to playback commands)
      if (root.title !== "") {
        var query = root.title
        if (root.artist !== "") {
          query = query + " " + root.artist
        }
        runAction("play \"" + query + "\" --json")
      } else {
        // Fallback to resume if we don't have track info
        runAction("resume --json")
      }
    }
  }

  function skip(direction) {
    if (!binaryPresent) return
    runAction(direction === "prev" ? "skip prev --json" : "skip --json")
  }

  function mood(name) {
    if (!binaryPresent) return
    root.lastMood = name
    runAction(name + " --json")
  }

  Process {
    id: currentProc
    command: ["/usr/bin/env", "spotify", "current", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.probed = true
        var raw = text ? ("" + text).trim() : ""
        if (!raw) return
        try {
          root.applyCurrent(JSON.parse(raw))
        } catch (e) {}
      }
    }
    onExited: function(code) {
      root.probed = true
      root.binaryPresent = (code === 0)
      if (code === 0) {
        root.hint = ""
        if (!watchProc.running)
          watchProc.running = true
      } else {
        root.hint = root.installHint
        root.binaryPresent = false
        console.warn("the-shit.music: spotify current exited", code)
      }
    }
  }

  Process {
    id: watchProc
    command: ["/usr/bin/env", "spotify", "watch", "--json", "--interval=3"]
    stdout: SplitParser {
      onRead: function(data) {
        var line = ("" + data).trim()
        if (!line) return
        try {
          root.applyWatch(JSON.parse(line))
        } catch (e) {}
      }
    }
    onExited: function(code) {
      console.warn("the-shit.music: spotify watch exited", code)
      pollTimer.start()
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: function() {
      root.actionBusy = false
      root.refresh()
    }
  }

  Timer {
    id: pollTimer
    interval: 5000
    repeat: true
    running: root.binaryPresent && !watchProc.running
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    console.log("the-shit.music service started")
    root.refresh()
  }
}

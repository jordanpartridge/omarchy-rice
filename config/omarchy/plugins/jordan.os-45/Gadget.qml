pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: true
  property bool alwaysOnTop: true
  property real cardX: -1
  property real cardY: -1
  property bool loadedState: false
  property bool punching: false
  property real sleeveDrop: 0
  property string localTitle: ""
  property string localArtist: ""
  property string localAlbum: ""
  property string localArtUrl: ""
  property bool localPlaying: false
  property var startColors: ({
    header: "#03140C", footer: "#03140C",
    ink: "#B6F5C0", muted: "#5C8A64",
    select: "#1AFF8C", paper: "#070B08",
    chrome: "xp"
  })

  readonly property string home: Quickshell.env("HOME")
  readonly property string catalogBin: home + "/.config/omarchy/plugins/jordan.os-45/bin/catalog"
  readonly property string statePath: home + "/.local/state/omarchy/jordan-os-45.json"
  readonly property string nowPlayingPath: home + "/.local/state/omarchy/jordan-os-nowplaying.json"
  readonly property string startOsPath: home + "/.config/omarchy/themes/jordan-os/start.json"
  readonly property string startXpPath: home + "/.config/omarchy/themes/jordan-xp/start.json"
  readonly property int margin: 16
  readonly property int barReserve: 52
  readonly property int discSize: 148
  readonly property color paper: String(startColors.paper || "#070B08")
  readonly property color ink: String(startColors.ink || "#B6F5C0")
  readonly property color muted: String(startColors.muted || "#5C8A64")
  readonly property color header: String(startColors.header || "#03140C")
  readonly property color select: String(startColors.select || "#1AFF8C")

  readonly property var media: shell ? shell.serviceFor("omarchy.media") : null
  readonly property var cli: shell ? shell.serviceFor("the-shit.music") : null
  readonly property bool mprisLive: !!(media && media.hasMedia)
  readonly property bool cliLive: !!(cli && cli.hasTrack)
  readonly property string title: mprisLive ? (media.title || "") : (cliLive ? (cli.title || "") : localTitle)
  readonly property string artist: mprisLive ? (media.artist || "") : (cliLive ? (cli.artist || "") : localArtist)
  readonly property string album: mprisLive ? (media.album || "") : (cliLive ? (cli.album || "") : localAlbum)
  readonly property string artUrl: mprisLive ? (media.artUrl || "") : (cliLive ? (cli.artUrl || "") : localArtUrl)
  readonly property bool isPlaying: {
    if (mprisLive && media.activePlayer)
      return !!media.activePlayer.isPlaying
    if (cliLive)
      return !!cli.isPlaying
    return localPlaying
  }
  readonly property bool hasTrack: title !== ""
  readonly property string sourceName: mprisLive ? "mpris" : (cliLive ? "cli" : (hasTrack ? "cli" : ""))

  function parseJson(text, fallback) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed
    } catch (error) {
    }
    return fallback
  }

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    if (payload.mode === "find" || payload.find === true) {
      root.openFind(payload.queue === true)
      return
    }
    if (payload.mode === "queue") {
      root.openFind(true)
      return
    }
    root.opened = true
    persist()
  }

  function close() {
    findOverlay.close()
    root.opened = false
    persist()
  }

  function toggle() {
    root.opened = !root.opened
    persist()
  }

  function openFind(queue) {
    findOverlay.open({ queue: !!queue })
  }

  function punch() {
    root.punching = false
    root.punching = true
    punchTimer.restart()
  }

  function doSkip() {
    root.punch()
    if (root.mprisLive && media && typeof media.runAction === "function") {
      if (media.runAction("next", true)) return
    }
    if (cli && typeof cli.skip === "function") {
      cli.skip("next")
      return
    }
    Quickshell.execDetached(["spotify", "skip", "--json"])
  }

  function doPlayPause() {
    root.punch()
    if (root.mprisLive && media && typeof media.runAction === "function") {
      if (media.runAction("playPause", true)) return
    }
    if (cli && typeof cli.playPause === "function") {
      cli.playPause()
      return
    }
    Quickshell.execDetached(["spotify", root.isPlaying ? "pause" : "resume", "--json"])
  }

  function applyState(obj) {
    if (!obj) return
    if (obj.x !== undefined) root.cardX = Number(obj.x)
    if (obj.y !== undefined) root.cardY = Number(obj.y)
    if (obj.visible === false) root.opened = false
    else if (obj.visible === true) root.opened = true
    root.alwaysOnTop = obj.alwaysOnTop !== false
    root.loadedState = true
    Qt.callLater(root.clamp)
  }

  function persist() {
    var payload = {
      x: Math.round(root.cardX),
      y: Math.round(root.cardY),
      visible: root.opened,
      alwaysOnTop: root.alwaysOnTop
    }
    stateFile.setText(JSON.stringify(payload) + "\n")
  }

  function persistNowPlaying() {
    var payload = {
      title: root.title,
      artist: root.artist,
      album: root.album,
      artUrl: root.artUrl,
      isPlaying: root.isPlaying,
      source: root.sourceName,
      ts: Date.now()
    }
    nowPlayingFile.setText(JSON.stringify(payload) + "\n")
  }

  function clamp() {
    if (!panel.screen) return
    var sw = panel.screen.width
    var sh = panel.screen.height
    var maxX = Math.max(root.margin, sw - card.width - root.margin)
    var maxY = Math.max(root.margin, sh - card.height - root.barReserve)
    if (root.cardX < 0 || root.cardY < 0 || root.cardX > sw || root.cardY > sh)
      root.placeCorner(2)
    root.cardX = Math.max(root.margin, Math.min(root.cardX, maxX))
    root.cardY = Math.max(root.margin, Math.min(root.cardY, maxY))
  }

  function placeCorner(which) {
    if (!panel.screen) return
    var sw = panel.screen.width
    var sh = panel.screen.height
    var xRight = sw - card.width - root.margin
    var yBottom = sh - card.height - root.barReserve
    if (which === 0) { root.cardX = root.margin; root.cardY = root.margin }
    else if (which === 1) { root.cardX = xRight; root.cardY = yBottom }
    else if (which === 3) { root.cardX = xRight; root.cardY = root.margin }
    else { root.cardX = root.margin; root.cardY = yBottom }
  }

  function applyCurrent(obj) {
    if (!obj || (!obj.name && !obj.track)) {
      root.localTitle = ""
      root.localArtist = ""
      root.localAlbum = ""
      root.localArtUrl = ""
      root.localPlaying = false
      return
    }
    root.localTitle = obj.name || obj.track || ""
    root.localArtist = obj.artist || ""
    root.localAlbum = obj.album || ""
    root.localArtUrl = obj.album_art_url || obj.artUrl || ""
    root.localPlaying = !!obj.is_playing
  }

  function refreshCli() {
    if (root.mprisLive || root.cliLive) return
    if (currentProc.running) currentProc.running = false
    currentProc.running = true
  }

  function statusJson() {
    return JSON.stringify({
      title: root.title,
      artist: root.artist,
      album: root.album,
      artUrl: root.artUrl,
      isPlaying: root.isPlaying,
      hasTrack: root.hasTrack,
      source: root.sourceName,
      findOpen: findOverlay.opened,
      gadgetOpen: root.opened
    })
  }

  onTitleChanged: persistNowPlaying()
  onArtUrlChanged: {
    sleeveDrop = -18
    dropAnim.restart()
    persistNowPlaying()
  }
  onIsPlayingChanged: persistNowPlaying()

  FindOverlay {
    id: findOverlay
    shell: root.shell
    catalogBin: root.catalogBin
    onPlayed: root.refreshCli()
  }

  FileView {
    id: startOsFile
    path: root.startOsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.startColors = root.parseJson(text(), root.startColors)
  }

  FileView {
    id: startXpFile
    path: root.startXpPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var osRaw = ""
      try { osRaw = startOsFile.text() } catch (e) {}
      if (String(osRaw || "").trim()) return
      root.startColors = root.parseJson(text(), root.startColors)
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyState(root.parseJson(text(), null))
    onLoadFailed: {
      root.loadedState = true
      Qt.callLater(function() { root.placeCorner(2); root.persist() })
    }
  }

  FileView {
    id: nowPlayingFile
    path: root.nowPlayingPath
    printErrors: false
  }

  Process {
    id: currentProc
    command: ["spotify", "current", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = text ? ("" + text).trim() : ""
        if (!raw) return
        try { root.applyCurrent(JSON.parse(raw)) } catch (e) {}
      }
    }
  }

  Timer {
    id: cliTimer
    interval: 4000
    repeat: true
    running: root.opened && !root.mprisLive && !root.cliLive
    onTriggered: root.refreshCli()
  }

  Timer {
    id: punchTimer
    interval: 220
    repeat: false
    onTriggered: root.punching = false
  }

  NumberAnimation {
    id: dropAnim
    target: root
    property: "sleeveDrop"
    to: 0
    duration: 180
    easing.type: Easing.OutCubic
  }

  IpcHandler {
    target: "jordan.os-45"
    function open(): void { root.open("") }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function snap(): void { root.placeCorner(2); root.opened = true; root.persist() }
    function find(): void { root.openFind(false) }
    function findClose(): void { findOverlay.close() }
    function queue(): void { root.openFind(true) }
    function skip(): void { root.doSkip() }
    function playPause(): void { root.doPlayPause() }
    function ping(): string { return "ok" }
    function status(): string { return root.statusJson() }
  }

  Component.onCompleted: root.refreshCli()

  PanelWindow {
    id: panel
    visible: root.opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "jordan-os-45"
    WlrLayershell.layer: root.alwaysOnTop ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    mask: Region { item: card }

    onVisibleChanged: if (visible) Qt.callLater(root.clamp)
    onScreenChanged: Qt.callLater(root.clamp)

    Rectangle {
      id: card
      x: Math.max(0, root.cardX)
      y: Math.max(0, root.cardY)
      width: root.discSize + 28
      height: inner.implicitHeight + 22
      radius: 8
      color: root.punching ? root.select : "#070B08"
      scale: root.punching ? 1.04 : 1.0
      border.width: root.punching ? 2 : 1
      border.color: root.select

      Behavior on color { ColorAnimation { duration: 140 } }
      Behavior on scale { NumberAnimation { duration: 140 } }

      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 6
        color: root.paper
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 3
        color: root.select
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 3
          color: root.header
        }
      }

      Column {
        id: inner
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        spacing: 8

        Item {
          id: disc
          width: root.discSize
          height: root.discSize

          Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#111111"
            border.width: 1
            border.color: "#2A2A2A"
          }

          Repeater {
            model: 7
            Rectangle {
              required property int index
              width: disc.width - (index + 1) * 12
              height: width
              radius: width / 2
              anchors.centerIn: disc
              color: "transparent"
              border.width: 1
              border.color: index % 2 === 0 ? "#1C1C1C" : "#161616"
            }
          }

          Item {
            id: sleeve
            width: disc.width * 0.42
            height: width
            anchors.horizontalCenter: disc.horizontalCenter
            anchors.verticalCenter: disc.verticalCenter
            anchors.verticalCenterOffset: root.sleeveDrop
            clip: true

            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: root.hasTrack ? "#2A1A12" : "#0C1810"
              border.width: 1
              border.color: root.select
              clip: true

              Image {
                anchors.fill: parent
                anchors.margins: 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: root.artUrl
                visible: root.artUrl !== ""
              }

              Text {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: "45"
                color: root.ink
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                font.bold: true
              }
            }

            Rectangle {
              width: 10
              height: 10
              radius: 5
              anchors.centerIn: parent
              color: "#050505"
              border.width: 1
              border.color: "#333333"
              z: 2
            }
          }
        }

        Text {
          width: disc.width
          text: root.hasTrack ? root.title : "Nothing playing"
          color: root.hasTrack ? root.ink : root.muted
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
          font.bold: true
          elide: Text.ElideRight
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: disc.width
          visible: root.artist !== ""
          text: root.artist
          color: root.muted
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 11
          elide: Text.ElideRight
          horizontalAlignment: Text.AlignHCenter
        }
      }

      MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: card
        drag.axis: Drag.XAndYAxis
        drag.minimumX: root.margin
        drag.minimumY: root.margin
        drag.maximumX: panel.screen ? panel.screen.width - card.width - root.margin : 10000
        drag.maximumY: panel.screen ? panel.screen.height - card.height - root.barReserve : 10000
        property bool dragged: false

        onPressed: dragged = false
        onPositionChanged: function(mouse) {
          if (pressed && (Math.abs(mouse.x) > 6 || Math.abs(mouse.y) > 6))
            dragged = true
        }
        onReleased: {
          root.cardX = card.x
          root.cardY = card.y
          root.clamp()
          card.x = root.cardX
          card.y = root.cardY
          root.persist()
        }
        onClicked: function(mouse) {
          if (dragged) return
          if (mouse.button === Qt.LeftButton) root.openFind(false)
          else if (mouse.button === Qt.RightButton) root.doPlayPause()
          else if (mouse.button === Qt.MiddleButton) root.doSkip()
        }
        onDoubleClicked: {
          root.placeCorner(2)
          root.persist()
        }
      }
    }

    Binding {
      target: card
      property: "x"
      value: root.cardX
      when: !dragArea.drag.active && root.cardX >= 0
    }
    Binding {
      target: card
      property: "y"
      value: root.cardY
      when: !dragArea.drag.active && root.cardY >= 0
    }
  }
}

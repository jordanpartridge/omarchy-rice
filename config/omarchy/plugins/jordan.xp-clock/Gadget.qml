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
  property var startColors: ({
    header: "#03140C", footer: "#03140C",
    ink: "#B6F5C0", muted: "#5C8A64",
    select: "#1AFF8C", paper: "#070B08",
    chrome: "xp"
  })

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/jordan-xp-clock.json"
  readonly property string startPath: home + "/.config/omarchy/themes/jordan-xp/start.json"
  readonly property int margin: 16
  readonly property int barReserve: 52
  readonly property color paper: "#070B08"
  readonly property color ink: "#B6F5C0"
  readonly property color muted: "#5C8A64"
  readonly property color header: "#03140C"
  readonly property color select: "#1AFF8C"

  function parseJson(text, fallback) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed
    } catch (error) {
    }
    return fallback
  }

  function open(payloadJson) {
    root.opened = true
    persist()
  }

  function close() {
    root.opened = false
    persist()
  }

  function toggle() {
    root.opened = !root.opened
    persist()
  }

  function applyState(obj) {
    if (!obj) return
    if (obj.x !== undefined) root.cardX = Number(obj.x)
    if (obj.y !== undefined) root.cardY = Number(obj.y)
    if (obj.visible === false) root.opened = false
    else if (obj.visible === true) root.opened = true
    root.alwaysOnTop = obj.alwaysOnTop === true
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

  function clamp() {
    if (!panel.screen) return
    var sw = panel.screen.width
    var sh = panel.screen.height
    var maxX = Math.max(root.margin, sw - card.width - root.margin)
    var maxY = Math.max(root.margin, sh - card.height - root.barReserve)
    if (root.cardX < 0 || root.cardY < 0)
      root.placeCorner(1)
    root.cardX = Math.max(root.margin, Math.min(root.cardX, maxX))
    root.cardY = Math.max(root.margin, Math.min(root.cardY, maxY))
  }

  // 0 top-left, 1 bottom-right (XP tray), 2 bottom-left, 3 top-right
  function placeCorner(which) {
    if (!panel.screen) return
    var sw = panel.screen.width
    var sh = panel.screen.height
    var xRight = sw - card.width - root.margin
    var yBottom = sh - card.height - root.barReserve
    if (which === 0) { root.cardX = root.margin; root.cardY = root.margin }
    else if (which === 2) { root.cardX = root.margin; root.cardY = yBottom }
    else if (which === 3) { root.cardX = xRight; root.cardY = root.margin }
    else { root.cardX = xRight; root.cardY = yBottom }
  }

  function nextCorner() {
    if (!panel.screen) return
    var sw = panel.screen.width
    var sh = panel.screen.height
    var cx = root.cardX + card.width / 2
    var cy = root.cardY + card.height / 2
    var idx = (cx >= sw / 2 ? 1 : 0) + (cy >= sh / 2 ? 2 : 0)
    // 0 TL, 1 TR, 2 BL, 3 BR  -> cycle BR, BL, TL, TR
    var order = [1, 2, 0, 3]
    var current = (cx >= sw / 2 ? 1 : 0) + (cy >= sh / 2 ? 2 : 0)
    var map = { 0: 0, 1: 3, 2: 2, 3: 1 }
    var logical = map[current] !== undefined ? map[current] : 1
    var next = (logical + 1) % 4
    placeCorner(next)
    persist()
  }

  FileView {
    id: startFile
    path: root.startPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.startColors = root.parseJson(text(), root.startColors)
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
      Qt.callLater(function() { root.placeCorner(1); root.persist() })
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  IpcHandler {
    target: "jordan.xp-clock"
    function open(): void { root.open("") }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function snap(): void { root.placeCorner(1); root.persist() }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "jordan-xp-clock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    mask: Region {
      item: card
    }

    onVisibleChanged: if (visible) Qt.callLater(root.clamp)
    onScreenChanged: Qt.callLater(root.clamp)

    Rectangle {
      id: card
      x: Math.max(0, root.cardX)
      y: Math.max(0, root.cardY)
      width: inner.implicitWidth + 28
      height: inner.implicitHeight + 22
      radius: 6
      color: "#070B08"
      opacity: 1.0
      border.width: 1
      border.color: root.select

      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 4
        color: root.paper
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 3
        radius: 0
        color: root.select
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 3
          color: root.header
        }
      }

      Row {
        id: inner
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        spacing: 22

        Text {
          id: timeText
          text: Qt.formatTime(clock.date, "HH:mm")
          color: "#B6F5C0"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 42
          font.bold: true
          font.letterSpacing: -1
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Text {
            text: Qt.formatDate(clock.date, "dddd")
            color: root.ink
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            font.bold: true
          }
          Text {
            text: Qt.formatDate(clock.date, "d MMMM yyyy")
            color: root.muted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Qt.formatTime(clock.date, "ss")
          color: root.select
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          font.bold: true
          opacity: 0.9
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

        onReleased: {
          root.cardX = card.x
          root.cardY = card.y
          root.clamp()
          card.x = root.cardX
          card.y = root.cardY
          root.persist()
        }
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.nextCorner()
          else if (mouse.button === Qt.MiddleButton) {
            root.alwaysOnTop = !root.alwaysOnTop
            root.persist()
          }
        }
        onDoubleClicked: {
          root.placeCorner(1)
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

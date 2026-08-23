pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property string catalogBin: ""
  property bool opened: false
  property bool queueMode: false
  property string query: ""
  property int selectedIndex: 0
  property bool searching: false
  property string hint: ""
  property string errorText: ""
  property bool shiftHeld: false

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int cardWidth: Math.min(Style.space(420), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(520), panel.height - Style.gapsOut * 2)

  signal played()

  function open(payload) {
    var p = payload || ({})
    root.queueMode = p.queue === true || p.mode === "queue"
    root.shiftHeld = false
    root.opened = true
    root.query = ""
    root.selectedIndex = 0
    root.searching = false
    root.hint = "Type at least 2 characters"
    root.errorText = ""
    hits.clear()
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.shiftHeld = false
    root.opened = false
    if (searchProc.running) searchProc.running = false
    if (playProc.running) playProc.running = false
  }

  function setQuery(next) {
    root.query = String(next || "")
    debounce.restart()
  }

  function typedChar(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      return ""
    var upper = root.shiftHeld || !!(event.modifiers & Qt.ShiftModifier)
    if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
      var base = String.fromCharCode(97 + (event.key - Qt.Key_A))
      return upper ? base.toUpperCase() : base
    }
    var ch = String(event.text || "")
    if (ch.length !== 1) return ""
    var code = ch.charCodeAt(0)
    if (code < 32 || code === 127) return ""
    if (upper && ch >= "a" && ch <= "z") return ch.toUpperCase()
    return ch
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Shift) {
      root.shiftHeld = true
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Escape) {
      root.close()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Down) {
      root.select(1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Up) {
      root.select(-1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_PageDown) {
      root.select(6)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_PageUp) {
      root.select(-6)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (hits.count > 0) root.activateIndex(root.selectedIndex)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Backspace) {
      if (event.modifiers & Qt.ControlModifier)
        root.setQuery("")
      else
        root.setQuery(root.query.slice(0, -1))
      event.accepted = true
      return
    }
    var ch = root.typedChar(event)
    if (ch !== "") {
      root.setQuery(root.query + ch)
      event.accepted = true
    }
  }

  function select(delta) {
    if (hits.count === 0) return
    root.selectedIndex = (root.selectedIndex + delta + hits.count) % hits.count
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function applySearch(raw) {
    root.searching = false
    hits.clear()
    var text = String(raw || "").trim()
    if (!text) {
      root.hint = "No matches"
      return
    }
    try {
      var obj = JSON.parse(text)
      if (obj && obj.ok === false) {
        root.errorText = String(obj.error || "search failed")
        root.hint = ""
        return
      }
      var tracks = (obj && obj.tracks) ? obj.tracks : []
      for (var i = 0; i < tracks.length && i < 12; i++) {
        var t = tracks[i]
        if (!t || !t.uri) continue
        hits.append({
          uri: String(t.uri || ""),
          name: String(t.name || ""),
          artist: String(t.artist || ""),
          album: String(t.album || "")
        })
      }
      root.selectedIndex = 0
      root.errorText = ""
      root.hint = hits.count === 0 ? "No matches" : ""
    } catch (e) {
      root.errorText = "search failed"
    }
  }

  function runSearch() {
    var q = String(root.query || "").trim()
    if (q.length < 2) {
      if (searchProc.running) searchProc.running = false
      hits.clear()
      root.searching = false
      root.hint = "Type at least 2 characters"
      root.errorText = ""
      return
    }
    if (!root.catalogBin) {
      root.errorText = "catalog helper missing"
      return
    }
    if (searchProc.running) searchProc.running = false
    root.searching = true
    root.errorText = ""
    root.hint = "Searching…"
    searchProc.command = [root.catalogBin, "search", q]
    searchProc.running = true
  }

  function activateIndex(index) {
    if (index < 0 || index >= hits.count) return
    var row = hits.get(index)
    if (!row || !row.uri) return
    if (playProc.running) return
    root.errorText = ""
    playProc.command = [root.catalogBin, root.queueMode ? "queue" : "play", row.uri]
    playProc.running = true
  }

  ListModel { id: hits }

  Timer {
    id: debounce
    interval: 280
    repeat: false
    onTriggered: root.runSearch()
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySearch(text)
    }
    onExited: function(code) {
      if (code !== 0 && root.searching && hits.count === 0 && !root.errorText)
        root.errorText = "search failed"
      root.searching = false
    }
  }

  Process {
    id: playProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        try {
          var obj = JSON.parse(raw)
          if (obj && obj.ok === false) {
            root.errorText = String(obj.error || "play failed")
            return
          }
        } catch (e) {
          root.errorText = "play failed"
          return
        }
        root.played()
        root.close()
      }
    }
    onExited: function(code) {
      if (code !== 0 && root.opened && !root.errorText)
        root.errorText = root.queueMode ? "queue failed" : "play failed"
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-keyboard-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    // Stay Exclusive while open so SUPER+SHIFT binds cannot steal letters.
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.handleKey(event) }
        Keys.onReleased: function(event) {
          if (event.key === Qt.Key_Shift) {
            root.shiftHeld = false
            event.accepted = true
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Text {
          Layout.fillWidth: true
          Layout.preferredHeight: root.headerHeight
          text: root.queueMode ? "Queue" : "Find"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          verticalAlignment: Text.AlignVCenter
        }

        TextField {
          id: queryField
          Layout.fillWidth: true
          text: root.query
          readOnly: true
          activeFocusOnPress: false
          placeholderText: root.queueMode ? "Queue a track…" : "Find a track…"
          font.family: root.fontFamily
          foreground: root.foreground
          accent: root.border
        }

        Text {
          Layout.fillWidth: true
          visible: root.errorText !== "" || (root.hint !== "" && hits.count === 0)
          text: root.errorText !== "" ? root.errorText : root.hint
          color: root.errorText !== "" ? root.selectedText : Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        ListView {
          id: resultList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: hits
          spacing: Style.space(4)
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property int index
            required property string uri
            required property string name
            required property string artist
            required property string album
            readonly property bool hasCursor: index === root.selectedIndex

            width: ListView.view.width
            height: root.rowHeight
            radius: root.cornerRadius
            color: hasCursor ? root.selectedBackground : "transparent"

            Column {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.topMargin: Style.space(8)
              anchors.bottomMargin: Style.space(8)
              spacing: 2

              Text {
                width: parent.width
                text: name
                color: hasCursor ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: artist + (album ? "  ·  " + album : "")
                color: hasCursor ? root.selectedText : Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectedIndex = index
              onClicked: root.activateIndex(index)
            }
          }
        }
      }
    }
  }
}

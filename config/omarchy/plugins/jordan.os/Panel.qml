pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "jordan.os"
  ipcTarget: "jordan.os"

  property string page: "start"
  property bool applying: false
  property var startColors: ({
    from: "#0A5C4A", to: "#0D6B4A",
    header: "#16485A", footer: "#12324A", bar_text: "#FFFEF8",
    ink: "#F4F1E4", muted: "#A8B4A8",
    select: "#0D5C5E", select_text: "#FFFEF8",
    paper: "#0A0C10", era: "xp", shape: "pill", room: "bliss"
  })
  property var options: ({
    era: "xp", room: "bliss", dont_paint: false,
    gaps: "classic", shadows: true,
    layouts: {
      mac: { bar: "top" }, "95": { bar: "bottom" },
      xp: { bar: "bottom" }, dos: { bar: "left" }
    }
  })
  property var nightPacket: ({})
  property var elonPacket: ({})
  property string spotifyTitle: ""
  property string spotifyArtist: ""
  property string spotifyAlbum: ""
  property string spotifyArt: ""
  property int hoverIndex: -1
  property bool cursorActive: false
  property int rowIndex: 0

  readonly property string home: Quickshell.env("HOME")
  readonly property string applyScript: home + "/.config/omarchy/themes/jordan-os/apply.sh"
  readonly property string optionsPath: home + "/.config/omarchy/themes/jordan-os/options.json"
  readonly property string startPath: home + "/.config/omarchy/themes/jordan-os/start.json"
  readonly property string nightPath: home + "/.local/state/omarchy/jordan-os/night-shift.json"
  readonly property string elonPath: home + "/.local/state/omarchy/jordan-os/elon.json"
  readonly property string iconDir: "file://" + home + "/.config/omarchy/plugins/jordan.os/icons/"
  readonly property string fontFamily: "JetBrainsMono Nerd Font"

  readonly property string era: String(options.era || startColors.era || "xp")
  readonly property bool eraMac: era === "mac"
  readonly property bool era95: era === "95"
  readonly property bool eraXp: era === "xp" || (!eraMac && !era95 && !eraDos)
  readonly property bool eraDos: era === "dos"

  readonly property color menuPaper: eraDos ? "#000028" : (eraMac ? "#0A1420" : "#070B08")
  readonly property color menuInk: eraDos ? "#55FF55" : (eraMac ? "#F2F7FC" : "#E8F0E8")
  readonly property color menuMuted: eraDos ? "#00AA00" : (eraMac ? "#7AA0C0" : "#8FA08F")
  readonly property color menuSelect: eraDos ? "#0000AA" : (eraMac ? "#0A3A6A" : "#052E1C")
  readonly property color menuSelectText: eraDos ? "#FFFF55" : "#FFFEF8"
  readonly property color menuAccent: eraDos ? "#55FF55" : (eraMac ? "#5AC8FA" : (era95 ? "#FFFFFF" : "#39FF14"))
  readonly property color startFrom: String(startColors.from || "#0A5C4A")
  readonly property color startTo: String(startColors.to || "#0D6B4A")
  readonly property bool verticalBar: !!(bar && (bar.position === "left" || bar.position === "right"))
  readonly property var currentRows: rowsForPage(page)

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property bool mprisHas: !!(mediaService && mediaService.hasMedia && String(mediaService.title || "") !== "")
  readonly property string sleeveTitle: mprisHas ? String(mediaService.title || "") : spotifyTitle
  readonly property string sleeveArtist: mprisHas ? String(mediaService.artist || "") : spotifyArtist
  readonly property string sleeveAlbum: mprisHas ? String(mediaService.album || "") : spotifyAlbum
  readonly property string sleeveArt: mprisHas ? String(mediaService.artUrl || "") : spotifyArt
  readonly property bool sleeveHas: sleeveTitle !== ""

  readonly property bool nightHas: packetPresent(nightPacket)
  readonly property bool elonHas: packetPresent(elonPacket)

  readonly property string pageTitle: {
    if (page === "display") return "Display Properties"
    if (page === "museum") return "Museum"
    if (page === "orgs") return "Orgs"
    if (page === "fleet") return "Fleet"
    if (page === "games") return "Games"
    if (page === "hobbies") return "Hobbies"
    return "Jordan OS"
  }

  readonly property var museumItems: [
    { label: "Orgs", hint: "the-shit · conduit · synapse", action: "page:orgs" },
    { label: "Fleet", hint: "Thor · Loki · Odin", action: "page:fleet" },
    { label: "Games", hint: "Elden Ring · RDR2 · bikes", action: "page:games" },
    { label: "Hobbies", hint: "bike · music · LEGO", action: "page:hobbies" }
  ]
  readonly property var orgItems: [
    { label: "jordanpartridge", hint: "personal", icon: "jordanpartridge", action: "url:https://github.com/jordanpartridge" },
    { label: "the-shit", hint: "If shit ain't tight…", icon: "the-shit", action: "url:https://github.com/the-shit" },
    { label: "conduit-ui", hint: "Integrate all the things", icon: "conduit-ui", action: "url:https://github.com/conduit-ui" },
    { label: "synapse-sentinel", hint: "Lexi + Forge", icon: "synapse-sentinel", action: "url:https://github.com/synapse-sentinel" },
    { label: "PSTrax", hint: "day job", icon: "PSTrax", action: "url:https://github.com/PSTrax" },
    { label: "PartridgeRocks", hint: "family shop", icon: "PartridgeRocks", action: "url:https://github.com/PartridgeRocks" }
  ]
  readonly property var fleetItems: [
    { label: "Thor", hint: "this box · Omarchy", action: "thor" },
    { label: "Loki", hint: "ssh loki · Pop!_OS", action: "ssh:loki" },
    { label: "Odin", hint: "ssh odin · homelab", action: "ssh:odin" },
    { label: "Asgard", hint: "jordanpartridge/Asgard", action: "url:https://github.com/jordanpartridge/Asgard" }
  ]
  readonly property var gameItems: [
    { label: "ELDEN RING", hint: "Steam", action: "steam:1245620" },
    { label: "Red Dead Redemption 2", hint: "Steam", action: "steam:1174180" },
    { label: "bikes", hint: "Grok 3D · momentum", action: "url:https://github.com/the-shit/bikes" },
    { label: "bikes-v2", hint: "zombie ebike · Mesa", action: "url:https://github.com/the-shit/bikes-v2" },
    { label: "unity-lego-games", hint: "Jordan + Nathan", action: "url:https://github.com/PartridgeRocks/unity-lego-games" }
  ]
  readonly property var hobbyItems: [
    { label: "Biker, not cyclist", hint: "dirt, not lycra", action: "url:https://www.jordanpartridge.us" },
    { label: "Music", hint: "the-shit/music", action: "music" },
    { label: "Homelab", hint: "self-hosted · Lexi", action: "url:https://github.com/synapse-sentinel" },
    { label: "LEGO + kids", hint: "site-words-studio", action: "url:https://github.com/jordanpartridge/site-words-studio" },
    { label: "Laravel", hint: "terminal maximalist", action: "url:https://github.com/conduit-ui" }
  ]

  function parseJson(text, fallback) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed
    } catch (error) {
    }
    return fallback
  }

  function packetPresent(obj) {
    if (!obj || typeof obj !== "object") return false
    var title = String(obj.title || obj.ask || obj.chewing || obj.body || "")
    return title.trim() !== ""
  }

  function packetTitle(obj, fallback) {
    if (!obj) return fallback
    var t = String(obj.title || obj.ask || obj.chewing || "")
    return t !== "" ? t : fallback
  }

  function packetBody(obj) {
    if (!obj) return ""
    return String(obj.body || obj.detail || obj.status || "")
  }

  function rowsForPage(name) {
    if (name === "museum") return museumItems
    if (name === "orgs") return orgItems
    if (name === "fleet") return fleetItems
    if (name === "games") return gameItems
    if (name === "hobbies") return hobbyItems
    return []
  }

  function runCmd(cmd) {
    if (!cmd || !cmd.length) return
    Quickshell.execDetached(cmd)
  }

  function activate(action) {
    if (!action) return
    if (action.indexOf("page:") === 0) {
      root.page = action.slice(5)
      root.rowIndex = 0
      root.hoverIndex = -1
      return
    }
    if (action.indexOf("era:") === 0) {
      root.setOption("era", action.slice(4))
      return
    }
    if (action.indexOf("url:") === 0) {
      runCmd(["omarchy-launch-browser", action.slice(4)])
      root.close()
      return
    }
    if (action.indexOf("steam:") === 0) {
      runCmd(["uwsm-app", "--", "steam", "steam://rungameid/" + action.slice(6)])
      root.close()
      return
    }
    if (action.indexOf("ssh:") === 0) {
      runCmd(["xdg-terminal-exec", "ssh", action.slice(4)])
      root.close()
      return
    }
    if (action === "terminal") runCmd(["xdg-terminal-exec"])
    else if (action === "browser") runCmd(["omarchy-launch-browser"])
    else if (action === "files") runCmd(["uwsm-app", "--", "nautilus"])
    else if (action === "grok") runCmd(["xdg-terminal-exec", "grok"])
    else if (action === "music") {
      runCmd(["omarchy", "menu", "summon", "music"])
    } else if (action === "thor") runCmd(["xdg-terminal-exec"])
    else if (action === "lock") runCmd(["omarchy", "system", "lock"])
    else if (action === "power") {
      if (root.bar && typeof root.bar.run === "function")
        root.bar.run("omarchy-shell shell toggle omarchy.power")
    } else if (action === "omarchy") {
      if (root.bar && typeof root.bar.run === "function")
        root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    } else if (action === "clock") {
      if (root.bar && typeof root.bar.run === "function")
        root.bar.run("omarchy-shell shell toggle jordan.os-clock")
    }
    if (action.indexOf("page:") !== 0 && action.indexOf("era:") !== 0) root.close()
  }

  function setOption(key, value) {
    if (root.applying) return
    root.applying = true
    applyProc.command = [root.applyScript, key, String(value)]
    applyProc.running = true
  }

  function goStart() {
    root.page = "start"
    root.rowIndex = 0
    root.hoverIndex = -1
  }

  function refreshSleeve() {
    if (root.mprisHas) return
    if (spotifyProc.running) spotifyProc.running = false
    spotifyProc.running = true
  }

  implicitWidth: startBtn.implicitWidth
  implicitHeight: startBtn.implicitHeight

  onOpenedChanged: if (root.opened) {
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    root.refreshSleeve()
  } else {
    root.page = "start"
    root.hoverIndex = -1
  }

  FileView {
    id: optionsFile
    path: root.optionsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.options = root.parseJson(text(), root.options)
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
    id: nightFile
    path: root.nightPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.nightPacket = root.parseJson(text(), ({}))
    onLoadFailed: root.nightPacket = ({})
  }

  FileView {
    id: elonFile
    path: root.elonPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.elonPacket = root.parseJson(text(), ({}))
    onLoadFailed: root.elonPacket = ({})
  }

  Process {
    id: applyProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: function() { root.applying = false }
  }

  Process {
    id: spotifyProc
    command: ["/usr/bin/env", "spotify", "current", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = text ? ("" + text).trim() : ""
        if (!raw) {
          root.spotifyTitle = ""
          root.spotifyArtist = ""
          root.spotifyAlbum = ""
          root.spotifyArt = ""
          return
        }
        try {
          var obj = JSON.parse(raw)
          var name = obj.name || obj.track || ""
          root.spotifyTitle = name || ""
          root.spotifyArtist = obj.artist || ""
          root.spotifyAlbum = obj.album || ""
          root.spotifyArt = obj.album_art_url || obj.artUrl || ""
        } catch (e) {
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.spotifyTitle = ""
        root.spotifyArtist = ""
        root.spotifyAlbum = ""
        root.spotifyArt = ""
      }
    }
  }

  Item {
    id: startBtn
    anchors.fill: parent
    implicitWidth: root.verticalBar ? Style.space(34) : Style.space(root.era95 ? 78 : 92)
    implicitHeight: Style.space(26)

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: root.eraXp ? height / 2 : (root.eraMac ? 6 : 0)
      border.width: root.era95 ? 2 : 1
      border.color: root.era95 ? "#FFFFFF" : (root.eraDos ? "#55FF55" : Qt.darker(root.startFrom, 1.35))
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: root.era95 ? "#DFDFDF" : (root.eraDos ? "#0000CC" : Qt.lighter(root.startTo, 1.15)) }
        GradientStop { position: 0.45; color: root.era95 ? "#C0C0C0" : (root.eraDos ? "#0000AA" : root.startTo) }
        GradientStop { position: 1.0; color: root.era95 ? "#A0A0A0" : (root.eraDos ? "#000088" : root.startFrom) }
      }

      // 95 inset bevel
      Rectangle {
        visible: root.era95
        anchors.fill: parent
        anchors.margins: 2
        color: "transparent"
        border.width: 1
        border.color: "#808080"
      }

      Row {
        anchors.centerIn: parent
        spacing: Style.space(6)
        visible: !root.verticalBar

        Row {
          visible: root.eraMac
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter
          Repeater {
            model: ["#FF5F57", "#FEBC2E", "#28C840"]
            Rectangle {
              required property string modelData
              width: 7
              height: 7
              radius: 4
              color: modelData
            }
          }
        }

        Grid {
          columns: 2
          rows: 2
          spacing: 1
          visible: root.eraXp
          anchors.verticalCenter: parent.verticalCenter
          Repeater {
            model: ["#E08A40", "#3EC8B2", "#E8C547", "#0A5C4A"]
            Rectangle {
              required property string modelData
              width: 5
              height: 5
              color: modelData
            }
          }
        }

        Text {
          text: root.eraDos ? "START" : (root.eraMac ? "OS" : "start")
          color: root.era95 ? "#000000" : (root.eraDos ? "#FFFF55" : "white")
          font.family: root.era95 ? "Liberation Sans" : (root.eraDos ? root.fontFamily : "Liberation Sans")
          font.pixelSize: Style.font.subtitle
          font.italic: root.eraXp
          font.bold: true
          style: root.eraXp ? Text.Raised : Text.Normal
          styleColor: "#06382c"
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Grid {
        visible: root.verticalBar
        anchors.centerIn: parent
        columns: 2
        rows: 2
        spacing: 1
        Repeater {
          model: root.eraMac ? ["#FF5F57", "#FEBC2E", "#28C840", "#5AC8FA"] : ["#E08A40", "#3EC8B2", "#E8C547", "#0A5C4A"]
          Rectangle {
            required property string modelData
            width: 6
            height: 6
            color: modelData
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          root.page = "display"
          root.open()
        } else if (mouse.button === Qt.MiddleButton) {
          root.activate("omarchy")
        } else {
          if (root.opened && root.page === "start") root.close()
          else { root.page = "start"; root.open() }
        }
      }
      onEntered: if (root.bar) root.bar.showTooltip(root, "Start — Jordan OS")
      onExited: if (root.bar) root.bar.hideTooltip(root)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: startBtn
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    padding: 0
    borderSpec: Border.flat(root.menuAccent, root.era95 ? 2 : 1)
    contentWidth: panel.fittedContentWidth(Style.space(root.page === "orgs" ? 500 : (root.page === "display" ? 440 : (root.eraDos && root.page === "start" ? 520 : 460))))
    contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: {
        if (root.page === "display" || root.page === "start") return
        var rows = root.currentRows
        if (root.rowIndex >= 0 && root.rowIndex < rows.length)
          root.activate(rows[root.rowIndex].action)
      }
      onMoveRequested: function(dx, dy) {
        if (root.page === "display" || root.page === "start") return
        var count = root.currentRows.length
        if (count <= 0) return
        root.cursorActive = true
        root.rowIndex = Math.max(0, Math.min(count - 1, root.rowIndex + dy))
      }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Backspace && root.page !== "start") {
          root.goStart()
          event.accepted = true
        }
      }

      Rectangle {
        id: paper
        anchors.fill: parent
        color: root.menuPaper
        radius: root.eraMac ? 8 : 0

        Column {
          id: body
          width: parent.width

          Rectangle {
            width: parent.width
            implicitHeight: headerRow.implicitHeight + Style.space(16)
            color: root.era95 ? "#000080" : (root.eraMac ? "transparent" : root.menuPaper)
            radius: root.eraMac ? 8 : 0

            Rectangle {
              visible: root.eraMac
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: 8
              radius: 8
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#FFFFFF" }
                GradientStop { position: 0.5; color: "#5AC8FA" }
                GradientStop { position: 1.0; color: "#007AFF" }
              }
            }

            Rectangle {
              visible: root.eraXp || root.eraDos
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: 2
              color: root.menuAccent
              z: 2
            }

            Row {
              id: headerRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(12)

              Row {
                visible: root.eraMac
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                  model: ["#FF5F57", "#FEBC2E", "#28C840"]
                  Rectangle {
                    required property string modelData
                    width: 10
                    height: 10
                    radius: 5
                    color: modelData
                    border.width: 1
                    border.color: Qt.darker(modelData, 1.2)
                  }
                }
              }

              Rectangle {
                id: faceArt
                width: 48
                height: 48
                radius: root.eraMac ? 8 : 6
                clip: true
                color: "#03140C"
                border.width: 1
                border.color: root.menuAccent
                Image {
                  anchors.fill: parent
                  anchors.margins: 1
                  source: root.iconDir + "jordan.png"
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  smooth: true
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - faceArt.width - parent.spacing - (root.eraMac ? 42 : 0)
                Text {
                  width: parent.width
                  text: root.pageTitle
                  color: root.era95 && root.page === "start" ? "#FFFFFF" : root.menuInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  wrapMode: Text.NoWrap
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  text: root.page === "start" ? "Biker, not cyclist" : (root.applying ? "Applying…" : "Backspace to go back")
                  color: root.era95 && root.page === "start" ? "#C0C0C0" : root.menuMuted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }

            MouseArea {
              visible: root.page !== "start"
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goStart()
            }
          }

          // Cabinet homepage
          Column {
            visible: root.page === "start"
            width: parent.width
            spacing: Style.space(8)

            Item { width: 1; height: Style.space(4) }

            // Sleeve / now-playing — always present; empty is empty.
            Rectangle {
              x: Style.space(10)
              width: parent.width - Style.space(20)
              implicitHeight: sleeveRow.implicitHeight + Style.space(12)
              color: "#03140C"
              border.width: 1
              border.color: root.menuAccent
              radius: root.eraMac ? 8 : (root.eraXp ? 4 : 0)

              Row {
                id: sleeveRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(8)
                spacing: Style.space(10)

                Rectangle {
                  width: 56
                  height: 56
                  radius: 2
                  color: "#000000"
                  border.width: 1
                  border.color: root.menuMuted
                  Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.sleeveArt
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.sleeveArt !== ""
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: root.sleeveArt === ""
                    text: "45"
                    color: root.menuMuted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 56 - parent.spacing
                  spacing: 2
                  Text {
                    width: parent.width
                    text: "sleeve"
                    color: root.menuMuted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 0.6
                  }
                  Text {
                    width: parent.width
                    text: root.sleeveHas ? root.sleeveTitle : "—"
                    color: root.menuInk
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    visible: root.sleeveHas && (root.sleeveArtist !== "" || root.sleeveAlbum !== "")
                    text: root.sleeveArtist + (root.sleeveAlbum !== "" ? "  ·  " + root.sleeveAlbum : "")
                    color: root.menuMuted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.runCmd(["omarchy", "menu", "summon", "music.find"])
                  root.close()
                }
              }
            }

            // Night-shift — collapse if no packet.
            Rectangle {
              visible: root.nightHas
              x: Style.space(10)
              width: parent.width - Style.space(20)
              implicitHeight: nightCol.implicitHeight + Style.space(12)
              color: "#03140C"
              border.width: 1
              border.color: root.menuAccent
              radius: root.eraMac ? 8 : (root.eraXp ? 4 : 0)

              Column {
                id: nightCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(8)
                spacing: 2
                Text {
                  text: "night-shift"
                  color: root.menuMuted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }
                Text {
                  width: nightCol.width
                  text: root.packetTitle(root.nightPacket, "")
                  color: root.menuInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  wrapMode: Text.WordWrap
                }
                Text {
                  width: nightCol.width
                  visible: root.packetBody(root.nightPacket) !== ""
                  text: root.packetBody(root.nightPacket)
                  color: root.menuMuted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }

            // Elon — collapse if no packet. Never invent a card.
            Rectangle {
              visible: root.elonHas
              x: Style.space(10)
              width: parent.width - Style.space(20)
              implicitHeight: elonCol.implicitHeight + Style.space(12)
              color: "#03140C"
              border.width: 1
              border.color: root.menuAccent
              radius: root.eraMac ? 8 : (root.eraXp ? 4 : 0)

              Column {
                id: elonCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(8)
                spacing: 2
                Text {
                  text: "Elon"
                  color: root.menuMuted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.6
                }
                Text {
                  width: elonCol.width
                  text: root.packetTitle(root.elonPacket, "")
                  color: root.menuInk
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  wrapMode: Text.WordWrap
                }
                Text {
                  width: elonCol.width
                  visible: root.packetBody(root.elonPacket) !== ""
                  text: root.packetBody(root.elonPacket)
                  color: root.menuMuted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }

            Item { width: 1; height: Style.space(2) }
          }

          Column {
            visible: root.page !== "start" && root.page !== "display"
            width: parent.width
            Repeater {
              model: root.currentRows
              MenuRow {
                required property var modelData
                required property int index
                width: parent.width
                item: modelData
                idx: index
                ink: root.menuInk
                mutedInk: root.menuMuted
              }
            }
          }

          Column {
            id: displayCol
            visible: root.page === "display"
            width: parent.width
            spacing: Style.space(10)

            Item { width: 1; height: Style.space(8) }

            Text {
              x: Style.space(12)
              width: parent.width - Style.space(24)
              text: root.applying ? "Applying…" : "Appearance  ·  era " + root.era
              color: root.menuInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            OptionRow { title: "Room"; keyName: "room"; choices: ["bliss", "dirt", "gold", "night", "soundtrack"] }
            OptionRow { title: "Don't-paint"; keyName: "dont_paint"; choices: ["on", "off"] }
            OptionRow { title: "Gaps"; keyName: "gaps"; choices: ["tight", "classic", "room"] }
            OptionRow { title: "Shadows"; keyName: "shadows"; choices: ["on", "off"] }
            OptionRow { title: "Bar (this era)"; keyName: "bar"; choices: ["top", "bottom", "left", "right"] }

            Text {
              x: Style.space(12)
              width: parent.width - Style.space(24)
              text: "Layout is remembered per era. Wallpapers follow room, unless don’t-paint. CLI: jordan-os"
              color: root.menuMuted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Item { width: 1; height: Style.space(4) }
          }

          Rectangle {
            width: parent.width
            implicitHeight: footerCol.implicitHeight + Style.space(10)
            color: root.era95 ? "#C0C0C0" : root.menuPaper

            Column {
              id: footerCol
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Row {
                x: Style.space(12)
                spacing: Style.space(8)
                FooterBtn { label: "Museum"; action: "page:museum"; inkOn: true }
                FooterBtn { label: "Display"; action: "page:display"; inkOn: true }
                FooterBtn { label: "Clock"; action: "clock"; inkOn: true }
                FooterBtn { label: "Lock"; action: "lock"; inkOn: true }
              }

              Row {
                x: Style.space(12)
                spacing: Style.space(6)
                EraKey { label: "Mac"; eraId: "mac" }
                EraKey { label: "95"; eraId: "95" }
                EraKey { label: "XP"; eraId: "xp" }
                EraKey { label: "DOS"; eraId: "dos" }
              }
            }
          }
        }
      }
    }
  }

  component MenuRow: Rectangle {
    id: row
    property var item: ({})
    property int idx: 0
    property bool folder: false
    property color ink: root.menuInk
    property color mutedInk: root.menuMuted
    readonly property string iconName: item && item.icon ? String(item.icon) : ""
    readonly property bool hot: (root.cursorActive && root.rowIndex === idx) || hover.containsMouse
    implicitHeight: Math.max(Style.space(34), rowInner.implicitHeight + Style.space(8))
    height: implicitHeight
    color: hot ? root.menuSelect : "transparent"

    RowLayout {
      id: rowInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Rectangle {
        visible: row.iconName !== ""
        width: 28
        height: 28
        radius: 4
        clip: true
        color: "#03140C"
        border.width: 1
        border.color: root.menuAccent
        Layout.alignment: Qt.AlignVCenter
        Image {
          anchors.fill: parent
          anchors.margins: 1
          source: row.iconName !== "" ? (root.iconDir + row.iconName + ".png") : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
        }
      }

      Text {
        text: row.item && row.item.label ? row.item.label : ""
        color: row.hot ? root.menuSelectText : root.menuInk
        font.family: root.fontFamily
        font.pixelSize: 13
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        text: row.folder ? "»" : (row.item && row.item.hint ? row.item.hint : "")
        color: row.hot ? root.menuSelectText : root.menuMuted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: hover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.rowIndex = row.idx }
      onClicked: root.activate(row.item.action)
    }
  }

  component FooterBtn: Rectangle {
    id: fbtn
    property string label: ""
    property string action: ""
    property bool inkOn: false
    implicitWidth: fLabel.implicitWidth + Style.space(16)
    implicitHeight: Style.space(24)
    radius: root.eraMac ? 6 : 3
    color: fHover.containsMouse ? root.menuSelect : (root.era95 ? "#C0C0C0" : "transparent")
    border.width: 1
    border.color: root.era95 ? "#808080" : root.menuAccent

    Text {
      id: fLabel
      anchors.centerIn: parent
      text: fbtn.label
      color: root.era95 ? "#000000" : root.menuInk
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: fHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.activate(fbtn.action)
    }
  }

  component EraKey: Rectangle {
    id: ekey
    property string label: ""
    property string eraId: ""
    readonly property bool current: root.era === eraId
    implicitWidth: eLabel.implicitWidth + Style.space(18)
    implicitHeight: Style.space(26)
    radius: root.eraMac ? 6 : 0
    color: current ? root.menuSelect : (eHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
    border.width: current ? 2 : 1
    border.color: current ? root.menuAccent : root.menuMuted

    Text {
      id: eLabel
      anchors.centerIn: parent
      text: ekey.label
      color: current ? root.menuSelectText : root.menuInk
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: current
    }

    MouseArea {
      id: eHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setOption("era", ekey.eraId)
    }
  }

  component OptionRow: Column {
    id: opt
    property string title: ""
    property string keyName: ""
    property var choices: []
    x: Style.space(12)
    width: displayCol.width - Style.space(24)
    spacing: Style.space(4)

    function currentValue() {
      if (opt.keyName === "shadows") return root.options.shadows ? "on" : "off"
      if (opt.keyName === "dont_paint") return root.options.dont_paint ? "on" : "off"
      if (opt.keyName === "bar") {
        var layouts = root.options.layouts || {}
        var layout = layouts[root.era] || {}
        return String(layout.bar || "")
      }
      return String(root.options[opt.keyName] || "")
    }

    Text {
      text: opt.title
      color: root.menuMuted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.6
    }

    Flow {
      width: parent.width
      spacing: Style.space(6)
      Repeater {
        model: opt.choices
        Button {
          required property string modelData
          text: modelData
          selected: opt.currentValue() === modelData
          bordered: true
          foreground: root.menuInk
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          enabled: !root.applying
          onClicked: root.setOption(opt.keyName, modelData)
        }
      }
    }
  }
}

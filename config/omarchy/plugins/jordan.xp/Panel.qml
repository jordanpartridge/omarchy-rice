pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "jordan.xp"
  ipcTarget: "jordan.xp"

  property string page: "start"
  property bool applying: false
  property var startColors: ({
    from: "#0A5C4A", to: "#0C6350",
    header: "#16485A", footer: "#12324A", bar_text: "#FFFEF8",
    ink: "#141414", muted: "#3A3A3A",
    select: "#0D5C5E", select_text: "#FFFEF8",
    paper: "#F4F1E4", chrome: "xp"
  })
  property var options: ({ variant: "luna", gaps: "classic", border: "luna", shadows: true, chrome: "xp", start: "classic" })
  property int hoverIndex: -1
  property bool cursorActive: false
  property int rowIndex: 0

  readonly property string home: Quickshell.env("HOME")
  readonly property string applyScript: home + "/.config/omarchy/themes/jordan-xp/apply.sh"
  readonly property string optionsPath: home + "/.config/omarchy/themes/jordan-xp/options.json"
  readonly property string startPath: home + "/.config/omarchy/themes/jordan-xp/start.json"
  // Start menu is a fixed dark hacker chrome, independent of window skins.
  readonly property color menuPaper: "#000000"
  readonly property color menuInk: "#D2FFD8"
  readonly property color menuMuted: "#6E9F76"
  readonly property color menuSelect: "#052E1C"
  readonly property color menuSelectText: "#E8FFE9"
  readonly property color headerBlue: "#000000"
  readonly property color footerBlue: "#000000"
  readonly property color menuAccent: "#39FF14"
  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property string iconDir: "file://" + home + "/.config/omarchy/plugins/jordan.xp/icons/"
  readonly property color startFrom: String(startColors.from || "#0A5C4A")
  readonly property color startTo: String(startColors.to || "#0C6350")
  readonly property bool verticalBar: !!(bar && (bar.position === "left" || bar.position === "right"))
  readonly property var currentRows: rowsForPage(page)
  readonly property string pageTitle: {
    if (page === "display") return "Display Properties"
    if (page === "orgs") return "Orgs"
    if (page === "fleet") return "Fleet"
    if (page === "games") return "Games"
    if (page === "hobbies") return "Hobbies"
    return "jordan@thor"
  }

  function parseJson(text, fallback) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed
    } catch (error) {
    }
    return fallback
  }

  readonly property var pinnedItems: [
    { label: "Terminal", hint: "foot", action: "terminal" },
    { label: "Browser", hint: "Chromium", action: "browser" },
    { label: "Files", hint: "Nautilus", action: "files" },
    { label: "GitHub", hint: "jordanpartridge", action: "url:https://github.com/jordanpartridge" },
    { label: "Grok", hint: "Build TUI", action: "grok" },
    { label: "Music", hint: "the-shit/music", action: "music" }
  ]
  readonly property var folderItems: [
    { label: "Orgs", hint: "the-shit · conduit · synapse", action: "page:orgs" },
    { label: "Fleet", hint: "Thor · Loki · Odin", action: "page:fleet" },
    { label: "Games", hint: "Elden Ring · RDR2 · bikes", action: "page:games" },
    { label: "Hobbies", hint: "bike · music · LEGO", action: "page:hobbies" },
    { label: "Display Properties", hint: "Luna tweaks", action: "page:display" },
    { label: "Clock", hint: "desktop gadget", action: "clock" }
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

  function rowsForPage(name) {
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
      runCmd(["omarchy", "menu", "summon", "music.find"])
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
        root.bar.run("omarchy-shell shell toggle jordan.xp-clock")
    }
    if (action.indexOf("page:") !== 0) root.close()
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

  implicitWidth: startBtn.implicitWidth
  implicitHeight: startBtn.implicitHeight

  onOpenedChanged: if (root.opened) {
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
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

  Process {
    id: applyProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: function() { root.applying = false }
  }

  Item {
    id: startBtn
    anchors.fill: parent
    implicitWidth: root.verticalBar ? Style.space(34) : Style.space(92)
    implicitHeight: Style.space(26)

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: height / 2
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(root.startTo, 1.15) }
        GradientStop { position: 0.45; color: root.startTo }
        GradientStop { position: 1.0; color: root.startFrom }
      }
      border.width: 1
      border.color: Qt.darker(root.startFrom, 1.35)

      Row {
        anchors.centerIn: parent
        spacing: Style.space(6)
        visible: !root.verticalBar

        Grid {
          columns: 2
          rows: 2
          spacing: 1
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
          text: "start"
          color: "white"
          font.family: "Liberation Sans"
          font.pixelSize: Style.font.subtitle
          font.italic: true
          font.bold: true
          style: Text.Raised
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
          model: ["#E08A40", "#3EC8B2", "#E8C547", "#0A5C4A"]
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
      onEntered: if (root.bar) root.bar.showTooltip(root, "Start — Jordan XP")
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
    borderSpec: Border.flat(root.menuAccent, 1)
    contentWidth: panel.fittedContentWidth(Style.space(root.page === "orgs" ? 500 : (root.page === "display" ? 440 : 460)))
    contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: {
        if (root.page === "display") return
        var rows = root.page === "start" ? root.pinnedItems : root.currentRows
        if (root.page === "start") {
          var all = root.pinnedItems.concat(root.folderItems)
          if (root.rowIndex >= 0 && root.rowIndex < all.length) root.activate(all[root.rowIndex].action)
        } else if (root.rowIndex >= 0 && root.rowIndex < rows.length) {
          root.activate(rows[root.rowIndex].action)
        }
      }
      onMoveRequested: function(dx, dy) {
        if (root.page === "display") return
        var count = root.page === "start" ? (root.pinnedItems.length + root.folderItems.length) : root.currentRows.length
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
        color: "#000000"

      Column {
        id: body
        width: parent.width

        Rectangle {
          width: parent.width
          implicitHeight: headerRow.implicitHeight + Style.space(16)
          color: "#000000"

          Rectangle {
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

            Rectangle {
              id: faceArt
              width: 48
              height: 48
              radius: 6
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
              width: parent.width - faceArt.width - parent.spacing
              Text {
                width: parent.width
                text: root.pageTitle
                color: root.menuInk
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: root.page === "start" ? "jordan@partridge.rocks · Mesa AZ" : (root.applying ? "Applying…" : "Backspace to go back")
                color: root.menuMuted
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

        // Start: two columns
        Row {
          visible: root.page === "start"
          width: parent.width
          height: Math.max(leftCol.implicitHeight, rightCol.implicitHeight)

          Column {
            id: leftCol
            width: parent.width * 0.48
            Repeater {
              model: root.pinnedItems
              MenuRow {
                required property var modelData
                required property int index
                width: leftCol.width
                item: modelData
                idx: index
                ink: root.menuInk
                mutedInk: root.menuMuted
              }
            }
          }

          Rectangle {
            width: 1
            height: parent.height
            color: "#1A3D28"
          }

          Column {
            id: rightCol
            width: parent.width * 0.52 - 1
            Repeater {
              model: root.folderItems
              MenuRow {
                required property var modelData
                required property int index
                width: rightCol.width
                item: modelData
                idx: root.pinnedItems.length + index
                folder: true
                ink: root.menuInk
                mutedInk: root.menuMuted
              }
            }
          }
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
            text: root.applying ? "Applying theme…" : "Appearance"
            color: root.menuInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          OptionRow { title: "Skin"; keyName: "variant"; choices: ["luna", "olive", "silver", "mesa", "erdtree"] }
          OptionRow { title: "Gaps"; keyName: "gaps"; choices: ["tight", "classic", "room"] }
          OptionRow { title: "Border"; keyName: "border"; choices: ["thin", "luna", "chunky"] }
          OptionRow { title: "Shadows"; keyName: "shadows"; choices: ["on", "off"] }
          OptionRow { title: "Chrome"; keyName: "chrome"; choices: ["xp", "mixed", "dark"] }
          OptionRow { title: "Start"; keyName: "start"; choices: ["classic", "bright", "gold"] }

          Text {
            x: Style.space(12)
            width: parent.width - Style.space(24)
            text: "Wallpapers: omarchy theme bg next  ·  CLI: jordan-xp"
            color: root.menuMuted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Item { width: 1; height: Style.space(4) }
        }

        Rectangle {
          width: parent.width
          height: Style.space(40)
          color: "#000000"

          Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            spacing: Style.space(8)

            FooterBtn { label: "Lock"; action: "lock" }
            FooterBtn { label: "Turn Off…"; action: "power" }
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
    color: hot ? "#052E1C" : "transparent"

    readonly property color labelColor: hot ? root.menuSelectText : ink

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
        color: row.hot ? "#E8FFE9" : root.menuInk
        font.family: root.fontFamily
        font.pixelSize: 13
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
        opacity: 1.0
      }

      Text {
        text: row.folder ? "»" : (row.item && row.item.hint ? row.item.hint : "")
        color: row.hot ? "#8CFFB0" : root.menuMuted
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
    implicitWidth: fLabel.implicitWidth + Style.space(16)
    implicitHeight: Style.space(24)
    radius: 3
    color: fHover.containsMouse ? "#0A3D28" : "transparent"
    border.width: 1
    border.color: root.menuAccent

    Text {
      id: fLabel
      anchors.centerIn: parent
      text: fbtn.label
      color: root.menuInk
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

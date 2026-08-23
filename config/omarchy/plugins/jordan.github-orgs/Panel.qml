pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "jordan.github-orgs"
  ipcTarget: "jordan.github-orgs"
  manageIpc: false

  property var snapshot: ({ updatedAt: "", attention: 0, error: null, orgs: [] })
  property int orgIndex: 0
  property bool userPickedOrg: false
  property bool fetching: false
  property bool cursorActive: false
  property int rowIndex: 0

  readonly property string fetchScript: Quickshell.env("HOME") + "/.config/omarchy/plugins/jordan.github-orgs/fetch.sh"
  readonly property string snapshotPath: Quickshell.env("HOME") + "/.local/state/omarchy/github-orgs.json"
  readonly property color foreground: "#B6F5C0"
  readonly property color dim: "#5C8A64"
  readonly property color urgent: "#FF5A5A"
  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property var orgs: Array.isArray(snapshot.orgs) ? snapshot.orgs : []
  readonly property var selectedOrg: orgs.length > 0 ? orgs[Math.max(0, Math.min(orgIndex, orgs.length - 1))] : null
  readonly property var items: selectedOrg && Array.isArray(selectedOrg.items) ? selectedOrg.items : []
  readonly property int attention: Number(snapshot.attention || 0)
  readonly property int openRowIndex: items.length
  readonly property string summary: snapshot.error ? "GitHub error"
    : fetching && orgs.length === 0 ? "Loading"
    : attention > 0 ? (attention + " need you")
    : "Quiet"

  function applySnapshot(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return
      root.snapshot = parsed
      if (!root.userPickedOrg) {
        var next = 0
        var list = Array.isArray(parsed.orgs) ? parsed.orgs : []
        for (var i = 0; i < list.length; i++) {
          if (Number(list[i].attention || 0) > 0) { next = i; break }
        }
        root.orgIndex = next
      } else if (root.orgIndex >= orgs.length) {
        root.orgIndex = Math.max(0, orgs.length - 1)
      }
      if (root.rowIndex > root.openRowIndex) root.rowIndex = root.openRowIndex
    } catch (error) {
    }
  }

  function snapshotAgeMs() {
    var stamp = snapshot && snapshot.updatedAt ? Date.parse(String(snapshot.updatedAt)) : NaN
    if (!isFinite(stamp)) return 1e15
    return Date.now() - stamp
  }

  function refresh(force) {
    if (fetchProc.running) return
    root.fetching = true
    fetchProc.command = force ? [root.fetchScript, "--force"] : [root.fetchScript]
    fetchProc.running = true
  }

  function selectOrg(index) {
    if (orgs.length === 0) return
    var wrapped = ((index % orgs.length) + orgs.length) % orgs.length
    root.userPickedOrg = true
    root.orgIndex = wrapped
    root.rowIndex = 0
    root.cursorActive = true
  }

  function moveCursor(dx, dy) {
    root.cursorActive = true
    if (dx !== 0) {
      selectOrg(root.orgIndex + dx)
      return
    }
    if (dy === 0) return
    var maxIndex = root.openRowIndex
    root.rowIndex = Math.max(0, Math.min(maxIndex, root.rowIndex + dy))
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["omarchy-launch-browser", String(url)])
    root.close()
  }

  function activateCursor() {
    if (!root.selectedOrg) return
    if (root.rowIndex >= items.length) {
      openUrl(selectedOrg.url)
      return
    }
    var item = items[root.rowIndex]
    if (item && item.url) openUrl(item.url)
  }

  function whyColor(why) {
    if (why === "night-ready" || why === "review") return root.urgent
    return root.dim
  }

  function whyLabel(why) {
    if (why === "night-ready") return "NIGHT"
    if (why === "review") return "REVIEW"
    if (why === "agent-ready") return "AGENT"
    return "RECENT"
  }

  function kindGlyph(kind) {
    return kind === "pr" ? "" : ""
  }

  function relativeTime(iso) {
    var stamp = Date.parse(String(iso || ""))
    if (!isFinite(stamp)) return ""
    var minutes = Math.max(0, Math.round((Date.now() - stamp) / 60000))
    if (minutes < 1) return "just now"
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.round(minutes / 60)
    if (hours < 36) return hours + "h ago"
    return Math.round(hours / 24) + "d ago"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (root.opened) {
    root.cursorActive = false
    root.rowIndex = 0
    if (root.snapshotAgeMs() > 90000) root.refresh(false)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  FileView {
    id: snapshotFile
    path: root.snapshotPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applySnapshot(text())
    onLoadFailed: {
    }
  }

  Process {
    id: fetchProc
    command: [root.fetchScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.fetching = false
        var raw = String(text || "").trim()
        if (raw) root.applySnapshot(raw)
        snapshotFile.reload()
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.fetching = false
    }
  }

  Timer {
    interval: 10 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh(false)
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(true); return "ok" }
    function status(): string { return root.summary }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰊤"
    active: root.attention > 0
    dimmed: !!root.snapshot.error
    tooltipText: "GitHub: " + root.summary
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.openUrl("https://github.com")
      else if (buttonCode === Qt.MiddleButton) root.refresh(true)
      else root.toggle()
    }
  }

  Rectangle {
    visible: root.attention > 0
    anchors.right: button.right
    anchors.top: button.top
    anchors.rightMargin: 1
    anchors.topMargin: 1
    z: 2
    width: Math.max(Style.space(11), badgeText.implicitWidth + Style.space(4))
    height: Style.space(11)
    radius: height / 2
    color: root.urgent

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: root.attention > 99 ? "99+" : String(root.attention)
      color: Color.background
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh(true) }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: root.selectedOrg ? String(root.selectedOrg.login) : "GitHub"
            meta: root.fetching ? "Refreshing" : root.summary
            detail: root.snapshot.updatedAt ? root.relativeTime(root.snapshot.updatedAt) : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.snapshot.error ? 0.5 : 1.0
            iconComponent: Component {
              Text {
                text: "󰊤"
                color: root.attention > 0 ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: !!root.snapshot.error
            width: parent.width
            text: String(root.snapshot.error || "")
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row {
            id: orgSwitch
            visible: root.orgs.length > 1
            width: parent.width
            spacing: Style.spacing.md
            readonly property real cellWidth: root.orgs.length > 0
              ? (width - spacing * (root.orgs.length - 1)) / root.orgs.length
              : 0

            Repeater {
              model: root.orgs
              Button {
                required property var modelData
                required property int index
                width: orgSwitch.cellWidth
                text: String(modelData.short || modelData.login || "")
                selected: index === root.orgIndex
                hasCursor: root.cursorActive && index === root.orgIndex && root.rowIndex < 0
                bordered: true
                foreground: Number(modelData.attention || 0) > 0 ? root.urgent : root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.selectOrg(index)
                onHovered: function(isHovered) { if (isHovered) root.cursorActive = true }
              }
            }
          }

          Row {
            visible: !!root.selectedOrg
            width: parent.width
            spacing: Style.space(18)

            StatCell { label: "ISSUES"; value: root.selectedOrg ? String(root.selectedOrg.issues) : "—" }
            StatCell { label: "PRS"; value: root.selectedOrg ? String(root.selectedOrg.prs) : "—" }
            StatCell { label: "NIGHT"; value: root.selectedOrg ? String(root.selectedOrg.nightReady) : "—"; hot: root.selectedOrg && Number(root.selectedOrg.nightReady) > 0 }
            StatCell { label: "AGENT"; value: root.selectedOrg ? String(root.selectedOrg.agentReady) : "—" }
            StatCell { label: "PARK"; value: root.selectedOrg ? String(root.selectedOrg.parked) : "—" }
          }

          PanelSeparator {
            visible: !!root.selectedOrg
            foreground: root.foreground
          }

          Column {
            visible: !!root.selectedOrg
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "HIGH VALUE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.items.length === 0
              width: parent.width
              text: "Nothing tagged night-ready or waiting on review. Recent activity is quiet too."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.items
              ItemRow {
                required property var modelData
                required property int index
                width: parent.width
                item: modelData
                cursorIndex: index
              }
            }
          }

          CursorSurface {
            id: openRow
            width: parent.width
            implicitHeight: openText.implicitHeight + Style.spacing.rowPaddingX
            hasCursor: root.cursorActive && root.rowIndex === root.openRowIndex
            foreground: root.foreground

            Text {
              id: openText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              text: root.selectedOrg ? ("Open " + root.selectedOrg.login + "  →") : "Open GitHub  →"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: { root.cursorActive = true; root.rowIndex = root.openRowIndex }
              onClicked: root.activateCursor()
            }
          }
        }
      }
    }
  }

  component StatCell: Column {
    property string label: ""
    property string value: ""
    property bool hot: false
    spacing: Style.space(4)

    Text {
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }
    Text {
      text: parent.value
      color: parent.hot ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
    }
  }

  component ItemRow: CursorSurface {
    id: row
    property var item: null
    property int cursorIndex: 0
    hasCursor: root.cursorActive && root.rowIndex === cursorIndex
    foreground: root.foreground
    implicitHeight: content.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.rowIndex = row.cursorIndex }
      onClicked: {
        root.rowIndex = row.cursorIndex
        root.activateCursor()
      }
    }

    RowLayout {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: root.kindGlyph(row.item ? row.item.kind : "")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: root.whyLabel(row.item ? row.item.why : "")
            color: root.whyColor(row.item ? row.item.why : "")
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
          }
          Text {
            Layout.fillWidth: true
            text: row.item ? (row.item.repo + "#" + row.item.number) : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        Text {
          Layout.fillWidth: true
          text: row.item ? String(row.item.title) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }
    }
  }
}

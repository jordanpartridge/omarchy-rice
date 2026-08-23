import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "the-shit.music"

  readonly property var music: bar?.shell?.serviceFor("the-shit.music")
  readonly property bool binaryPresent: music ? music.binaryPresent : false
  readonly property bool hasTrack: music ? music.hasTrack : false
  readonly property bool isPlaying: music ? music.isPlaying : false
  readonly property string title: music ? (music.title || "") : ""
  readonly property string artist: music ? (music.artist || "") : ""
  readonly property string album: music ? (music.album || "") : ""
  readonly property string artUrl: music ? (music.artUrl || "") : ""
  readonly property string playIcon: isPlaying ? "󰏤" : "󰐊"

  property bool popupOpen: false
  property real maxLabelWidth: 180

  function close() { popupOpen = false }

  visible: true
  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      text: binaryPresent ? playIcon : "🎵"
      color: !binaryPresent
        ? Qt.darker(root.bar.barForeground, 1.8)
        : (isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5))
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.title !== ""

      Text {
        id: labelText
        text: root.title + (root.artist ? "  ·  " + root.artist : "")
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter

        property bool needsScroll: implicitWidth > scrollClip.width

        NumberAnimation on x {
          running: labelText.needsScroll && !root.popupOpen && !root.bar.vertical
          loops: Animation.Infinite
          duration: Math.max(6000, labelText.implicitWidth * 25)
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) {
        if (root.music) root.music.skip("next")
      } else if (mouse.button === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
      } else {
        if (root.hasTrack && root.music) root.music.playPause()
        else root.popupOpen = !root.popupOpen
      }
    }
    onEntered: {
      if (!root.bar) return
      var tip = !binaryPresent
        ? "the-shit/music — spotify not on PATH"
        : (root.hasTrack ? (root.title + (root.artist ? " — " + root.artist : "")) : "the-shit/music")
      root.bar.showTooltip(root, tip)
    }
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor("#B6F5C0", Color.accent)
          borderSpec: Border.controlSpec("normal", "#B6F5C0", Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.artUrl
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: "🎵"
            color: "#B6F5C0"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            text: !binaryPresent
              ? "spotify CLI missing"
              : (root.title || "Nothing playing")
            color: "#B6F5C0"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: !binaryPresent
              ? "composer global require the-shit/music"
              : root.artist
            color: Qt.darker("#B6F5C0", 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            text: root.album
            color: Qt.darker("#B6F5C0", 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: binaryPresent && text !== ""
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        visible: binaryPresent

        Button {
          iconText: "󰒮"
          foreground: "#B6F5C0"
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.hasTrack
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.music) root.music.skip("prev")
        }

        Button {
          iconText: root.playIcon
          foreground: "#B6F5C0"
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.hasTrack
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.music) root.music.playPause()
        }

        Button {
          iconText: "󰒭"
          foreground: "#B6F5C0"
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.hasTrack
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.music) root.music.skip("next")
        }
      }

      PanelSeparator {
        visible: binaryPresent
        foreground: "#B6F5C0"
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        visible: binaryPresent

        Button {
          text: "chill"
          foreground: "#B6F5C0"
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.music && !root.music.actionBusy
          onClicked: if (root.music) root.music.mood("chill")
        }

        Button {
          text: "flow"
          foreground: "#B6F5C0"
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.music && !root.music.actionBusy
          onClicked: if (root.music) root.music.mood("flow")
        }

        Button {
          text: "hype"
          foreground: "#B6F5C0"
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.music && !root.music.actionBusy
          onClicked: if (root.music) root.music.mood("hype")
        }
      }
    }
  }
}

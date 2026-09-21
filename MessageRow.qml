import QtQuick
import Quickshell
import qs.Commons
import "Format.js" as Format

// One message. `header` shows avatar, name and time; a follow-up from the
// same sender within a few minutes hides them and just adds the body.
// Links are clickable and open in the default browser.
Item {
  id: root
  property string sender: ""
  property string senderName: ""
  property string body: ""
  property string html: ""
  property real ts: 0
  property bool mine: false
  property bool encrypted: true
  property bool header: true
  property string dayLabel: ""
  property color fg: Color.foreground
  property color accent: Color.accent
  property color bg: Color.popups.background
  property string fontFamily: Style.font.family
  property bool bubbles: false
  property bool showAvatars: true
  property bool senderColors: true
  property real scale: 1.0

  readonly property real bodySize: Style.font.body * scale
  readonly property real captionSize: Style.font.caption * scale
  readonly property real avatarSize: Style.space(32) * scale
  readonly property bool avatar: showAvatars && !(bubbles && mine)
  readonly property real gutter: avatar ? avatarSize + Style.space(12) : 0
  readonly property color nameColor: mine ? accent : (senderColors ? Qt.hsla(Format.hueFor(sender) / 360, 0.6, 0.62, 1) : fg)

  implicitHeight: column.implicitHeight + (header ? Style.space(8) : Style.space(2))

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: root.header ? Style.space(6) : 0
    spacing: Style.space(2)

    // Day divider
    Item {
      width: parent.width
      visible: root.dayLabel !== ""
      implicitHeight: visible ? Style.space(28) : 0
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: root.fg; opacity: 0.12 }
      Rectangle {
        anchors.centerIn: parent
        width: dayText.implicitWidth + Style.space(16)
        height: dayText.implicitHeight + Style.space(6)
        radius: height / 2
        color: root.bg
        border.color: root.fg
        border.width: 1
        opacity: 0.9
        Text {
          id: dayText
          anchors.centerIn: parent
          text: root.dayLabel
          color: root.fg
          opacity: 0.7
          font.family: root.fontFamily
          font.pixelSize: root.captionSize
        }
      }
    }

    Item {
      width: parent.width
      implicitHeight: Math.max(root.avatar && root.header ? root.avatarSize : 0, textColumn.implicitHeight)

      Rectangle {
        visible: !root.bubbles
        anchors.fill: parent
        anchors.leftMargin: -Style.space(6)
        anchors.rightMargin: -Style.space(6)
        radius: Style.space(4)
        color: rowMouse.containsMouse ? Util.alpha(root.fg, 0.05) : "transparent"
      }
      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
      }

      Avatar {
        visible: root.avatar && root.header
        anchors.left: parent.left
        anchors.top: parent.top
        userId: root.sender
        name: root.senderName
        size: root.avatarSize
        fontFamily: root.fontFamily
      }

      // Time on hover for grouped messages (flat style)
      Text {
        visible: !root.bubbles && root.avatar && !root.header && rowMouse.containsMouse
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Style.space(2)
        width: root.avatarSize
        horizontalAlignment: Text.AlignHCenter
        text: Qt.formatTime(new Date(root.ts), "HH:mm")
        color: root.fg
        opacity: 0.4
        font.family: root.fontFamily
        font.pixelSize: root.captionSize - 1
      }

      Column {
        id: textColumn
        anchors.left: parent.left
        anchors.leftMargin: root.gutter
        anchors.right: parent.right
        spacing: Style.space(1)

        Row {
          visible: root.header && !(root.bubbles && root.mine)
          anchors.right: root.bubbles && root.mine ? parent.right : undefined
          spacing: Style.space(8)
          Text {
            text: root.senderName
            color: root.nameColor
            font.family: root.fontFamily
            font.pixelSize: root.bodySize
            font.bold: true
          }
          Text {
            anchors.baseline: parent.children[0].baseline
            text: Qt.formatTime(new Date(root.ts), "HH:mm") + (root.encrypted ? "" : "  󰌿 unencrypted")
            color: root.encrypted ? root.fg : Color.urgent
            opacity: root.encrypted ? 0.45 : 0.8
            font.family: root.fontFamily
            font.pixelSize: root.captionSize
          }
        }

        // Body: plain in flat style, inside a rounded bubble in bubble style.
        Item {
          width: parent.width
          implicitHeight: bubble.implicitHeight

          Rectangle {
            id: bubble
            anchors.right: root.bubbles && root.mine ? parent.right : undefined
            anchors.left: root.bubbles && root.mine ? undefined : parent.left
            width: root.bubbles ? Math.min(bodyText.implicitWidth + Style.space(24), parent.width * 0.78) : parent.width
            implicitHeight: bodyText.implicitHeight + (root.bubbles ? Style.space(16) : 0)
            radius: root.bubbles ? Style.space(14) : 0
            color: !root.bubbles ? "transparent" : (root.mine ? root.accent : Util.alpha(root.fg, 0.1))

            Text {
              id: bodyText
              anchors.fill: parent
              anchors.margins: root.bubbles ? Style.space(8) : 0
              anchors.leftMargin: root.bubbles ? Style.space(12) : 0
              anchors.rightMargin: root.bubbles ? Style.space(12) : 0
              textFormat: Text.RichText
              text: root.html !== "" ? Format.cleanHtml(root.html) : Format.linkify(root.body)
              wrapMode: Text.Wrap
              color: root.bubbles && root.mine ? root.bg : root.fg
              linkColor: root.bubbles && root.mine ? root.bg : root.accent
              font.family: root.fontFamily
              font.pixelSize: root.bodySize
              onLinkActivated: function(link) { Quickshell.execDetached(["omarchy-launch-browser", link]) }
              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
              }
            }
          }
        }

        // Bubble style: time under your own bubbles on the first of a run
        Text {
          visible: root.bubbles && root.mine && root.header
          anchors.right: parent.right
          text: Qt.formatTime(new Date(root.ts), "HH:mm") + (root.encrypted ? "" : "  󰌿")
          color: root.encrypted ? root.fg : Color.urgent
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: root.captionSize
        }
      }
    }
  }
}

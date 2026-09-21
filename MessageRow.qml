import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
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
  property string msgtype: "m.text"
  property var attachment: null
  property string roomId: ""
  property string eventId: ""
  property var service: null
  property real ts: 0
  property bool mine: false
  property bool encrypted: true
  property bool header: true
  property string dayLabel: ""
  property color fg: Color.foreground
  property color accent: Color.accent
  property color bg: Color.popups.background
  property color hover: Util.alpha(Color.foreground, 0.05)
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
  readonly property bool isAttachment: attachment !== null && attachment !== undefined
  readonly property bool isImage: isAttachment && attachment.kind === "image"
  property string thumbPath: ""
  property bool fetching: false
  property string fetchError: ""

  // Thumbnails load lazily; the daemon caches so re-created rows are cheap.
  function loadThumb() {
    if (!root.isImage || root.thumbPath !== "" || root.fetching || !root.service) return
    root.fetching = true
    root.service.download(root.roomId, root.eventId, true, function(r) {
      root.fetching = false
      if (r.ok) root.thumbPath = r.result.path
      else root.fetchError = r.error || "Could not load"
    })
  }
  Component.onCompleted: loadThumb()
  onEventIdChanged: { thumbPath = ""; loadThumb() }

  function openFull() {
    if (!root.service) return
    root.fetching = true
    root.service.download(root.roomId, root.eventId, false, function(r) {
      root.fetching = false
      if (r.ok) root.service.openPath(r.result.path)
      else root.fetchError = r.error || "Could not download"
    })
  }

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
        color: rowMouse.containsMouse ? root.hover : "transparent"
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

        // Image attachment: thumbnail sized by the sender's dimensions
        Item {
          visible: root.isImage
          width: parent.width
          implicitHeight: visible ? imageFrame.height : 0

          Rectangle {
            id: imageFrame
            readonly property real maxW: Math.min(parent.width, Style.space(420))
            readonly property real srcW: root.isImage && root.attachment.width ? Number(root.attachment.width) : 4
            readonly property real srcH: root.isImage && root.attachment.height ? Number(root.attachment.height) : 3
            readonly property real ratio: Math.max(0.2, Math.min(3, srcH / srcW))
            anchors.right: root.bubbles && root.mine ? parent.right : undefined
            anchors.left: root.bubbles && root.mine ? undefined : parent.left
            width: Math.min(maxW, thumb.status === Image.Ready ? Math.max(Style.space(120), thumb.implicitWidth) : maxW)
            height: Math.min(Style.space(420), Math.round(width * ratio))
            radius: Style.space(10)
            color: Util.alpha(root.fg, 0.08)
            clip: true

            Image {
              id: thumb
              anchors.fill: parent
              source: root.thumbPath !== "" ? "file://" + root.thumbPath : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 1280
            }
            Column {
              anchors.centerIn: parent
              visible: thumb.status !== Image.Ready
              spacing: Style.space(4)
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.fetchError !== "" ? "󰋩" : "󰋩"
                color: root.fg; opacity: 0.4
                font.family: root.fontFamily; font.pixelSize: Style.font.display
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.fetchError !== "" ? root.fetchError : (root.fetching || root.thumbPath === "" ? "Loading…" : "")
                color: root.fg; opacity: 0.5
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openFull()
              hoverEnabled: true
              onEntered: caption.opacity = 1
              onExited: caption.opacity = 0
            }
            // Filename + size on hover
            Rectangle {
              id: caption
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: captionText.implicitHeight + Style.space(10)
              color: Util.alpha("#000000", 0.55)
              opacity: 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
              Text {
                id: captionText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: root.attachment ? root.attachment.name + (root.attachment.size ? "  ·  " + Format.fileSize(root.attachment.size) : "") : ""
                color: "#ffffff"
                elide: Text.ElideRight
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // File / video / audio attachment: a card with name, size and Open
        Rectangle {
          visible: root.isAttachment && !root.isImage
          anchors.right: root.bubbles && root.mine ? parent.right : undefined
          anchors.left: root.bubbles && root.mine ? undefined : parent.left
          width: Math.min(parent.width, Style.space(360))
          implicitHeight: visible ? Style.space(56) : 0
          radius: Style.space(10)
          color: Util.alpha(root.fg, 0.08)
          border.width: 1
          border.color: Util.alpha(root.fg, 0.15)
          Row {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(10)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.attachment && root.attachment.kind === "video" ? "󰕧" : (root.attachment && root.attachment.kind === "audio" ? "󰝚" : "󰈔")
              color: root.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(10) * 2 - Style.space(28) - openButton.width
              spacing: Style.space(1)
              Text {
                width: parent.width
                text: root.attachment ? root.attachment.name : ""
                color: root.fg
                elide: Text.ElideMiddle
                font.family: root.fontFamily; font.pixelSize: root.bodySize
              }
              Text {
                width: parent.width
                text: root.attachment ? ((root.attachment.size ? Format.fileSize(root.attachment.size) : "") + (root.attachment.mime ? "  ·  " + root.attachment.mime : "")) : ""
                color: root.fg; opacity: 0.55
                elide: Text.ElideRight
                font.family: root.fontFamily; font.pixelSize: root.captionSize
              }
            }
            Button {
              id: openButton
              anchors.verticalCenter: parent.verticalCenter
              text: root.fetching ? "…" : "Open"
              iconText: "󰈔"
              bordered: true
              enabled: !root.fetching
              onClicked: root.openFull()
            }
          }
        }

        // Body: plain in flat style, inside a rounded bubble in bubble style.
        Item {
          // An attachment's body is just its filename; show it only when it is a caption.
          visible: !root.isAttachment || (root.attachment && root.body !== root.attachment.name)
          width: parent.width
          implicitHeight: visible ? bubble.implicitHeight : 0

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
              text: root.msgtype === "unable_to_decrypt"
                ? "<i>󰌾 Unable to decrypt — this device did not have the key. It fills in once backup or another device shares it.</i>"
                : (root.html !== "" ? Format.cleanHtml(root.html) : Format.linkify(root.body))
              wrapMode: Text.Wrap
              opacity: root.msgtype === "unable_to_decrypt" ? 0.6 : 1
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

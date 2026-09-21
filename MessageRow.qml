import QtQuick
import QtQuick.Effects
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
  property string senderAvatar: ""
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
  property bool roomEncrypted: false
  property bool header: true
  property string dayLabel: ""
  property bool newDivider: false
  property var replyTo: null
  property bool edited: false
  property bool deleted: false
  property bool highlighted: false
  property bool canEdit: false
  property bool canDelete: false
  property bool mention: false
  property bool linkPreviews: true
  // The sender is a bridge puppet for this network ("WhatsApp"), shown by the name.
  property string via: ""
  // Thread summary on a root ({replies, latest_ts, latest_sender_name}),
  // whether this row sits inside a thread view, and whether it is that
  // thread's root (drawn as the opening post).
  property var threadInfo: null
  property bool inThread: false
  property bool isThreadRoot: false
  signal threadRequested()
  property var preview: null
  property bool previewAsked: false
  readonly property string firstUrl: root.deleted || root.isAttachment ? "" : Format.firstUrl(root.body)
  function loadPreview() {
    if (!root.linkPreviews || root.previewAsked || root.firstUrl === "" || !root.service) return
    root.previewAsked = true
    // The row may be gone by the time the reply lands (list rebuilt).
    root.service.preview(root.firstUrl, function(p) { if (root) root.preview = p })
  }
  onFirstUrlChanged: { previewAsked = false; preview = null; loadPreview() }
  onLinkPreviewsChanged: loadPreview()
  property var reactions: []
  property var readBy: []
  property bool paletteOpen: false
  readonly property var quickEmoji: ["👍", "❤️", "😂", "😮", "😢", "🎉", "🔥", "👀"]

  signal replyRequested()
  signal editRequested()
  signal deleteRequested()
  signal reactRequested(string key)
  signal jumpRequested(string eventId)
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
  readonly property bool isSystem: msgtype === "system"
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
      if (!root) return
      root.fetching = false
      if (r.ok) root.thumbPath = r.result.path
      else root.fetchError = r.error || "Could not load"
    })
  }
  Component.onCompleted: { loadThumb(); loadPreview() }
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

  implicitHeight: isSystem ? systemLine.implicitHeight + Style.space(6) : column.implicitHeight + (header ? Style.space(8) : (isAttachment ? Style.space(6) : Style.space(2)))

  // Membership changes: one quiet centred line, no avatar or header.
  Item {
    id: systemLine
    visible: root.isSystem
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: Style.space(3)
    implicitHeight: sysText.implicitHeight
    Text {
      id: sysText
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width, implicitWidth)
      text: root.body
      color: root.fg; opacity: 0.45
      elide: Text.ElideRight
      font.family: root.fontFamily; font.pixelSize: root.captionSize
    }
  }

  Column {
    id: column
    visible: !root.isSystem
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: root.header ? Style.space(6) : 0
    spacing: Style.space(2)

    // "New messages" line: where you left off
    Item {
      width: parent.width
      visible: root.newDivider
      implicitHeight: visible ? Style.space(24) : 0
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: root.accent; opacity: 0.7 }
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: newText.implicitWidth + Style.space(14)
        height: newText.implicitHeight + Style.space(4)
        radius: Style.space(4)
        color: root.accent
        Text {
          id: newText
          anchors.centerIn: parent
          text: "New"
          color: root.bg
          font.family: root.fontFamily
          font.pixelSize: root.captionSize
          font.bold: true
        }
      }
    }

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
        anchors.fill: parent
        anchors.leftMargin: -Style.space(6)
        anchors.rightMargin: -Style.space(6)
        radius: Style.space(4)
        color: root.highlighted ? Util.alpha(root.accent, 0.18) : root.mention ? Util.alpha(Color.urgent, 0.08) : (rowMouse.containsMouse && !root.bubbles ? root.hover : "transparent")
        Behavior on color { ColorAnimation { duration: 200 } }
      }
      // Mentions get a bar on the left, like Element
      Rectangle {
        visible: root.mention
        anchors.left: parent.left
        anchors.leftMargin: -Style.space(6)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        radius: 2
        color: Color.urgent
      }
      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
      }

      // Hover actions: Reply, and Edit on your own text messages
      Rectangle {
        id: actions
        visible: (rowMouse.containsMouse || actionsMouse.containsMouse || root.paletteOpen) && root.msgtype !== "unable_to_decrypt" && !root.deleted
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -Style.space(10)
        z: 5
        width: actionsRow.implicitWidth + Style.space(8)
        height: Style.space(30)
        radius: Style.space(6)
        color: root.bg
        border.width: 1
        border.color: Util.alpha(root.fg, 0.25)
        MouseArea { id: actionsMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        Row {
          id: actionsRow
          anchors.centerIn: parent
          spacing: Style.space(2)
          Repeater {
            model: {
              var a = [{ icon: "󰞅", tip: "React", act: "react" }, { icon: "󰑚", tip: "Reply", act: "reply" }]
              if (!root.inThread && !root.deleted && root.msgtype !== "system") a.push({ icon: "󰻞", tip: "Thread", act: "thread" })
              if (root.canEdit) a.push({ icon: "󰏫", tip: "Edit", act: "edit" })
              if (root.canDelete) a.push({ icon: "󰆴", tip: "Delete", act: "delete" })
              return a
            }
            delegate: Rectangle {
              required property var modelData
              width: Style.space(26); height: Style.space(26)
              radius: Style.space(5)
              color: aMouse.containsMouse ? root.hover : "transparent"
              Text { anchors.centerIn: parent; text: parent.modelData.icon; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
              MouseArea {
                id: aMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var act = parent.modelData.act
                  if (act === "reply") root.replyRequested()
                  else if (act === "thread") root.threadRequested()
                  else if (act === "edit") root.editRequested()
                  else if (act === "delete") root.deleteRequested()
                  else root.paletteOpen = !root.paletteOpen
                }
              }
            }
          }
        }
      }

      // Quick reaction palette
      Rectangle {
        visible: root.paletteOpen
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Style.space(22)
        z: 6
        width: paletteRow.implicitWidth + Style.space(12)
        height: Style.space(40)
        radius: Style.space(8)
        color: root.bg
        border.width: 1
        border.color: Util.alpha(root.fg, 0.25)
        Row {
          id: paletteRow
          anchors.centerIn: parent
          spacing: Style.space(2)
          Repeater {
            model: root.quickEmoji
            delegate: Rectangle {
              required property string modelData
              width: Style.space(32); height: Style.space(32)
              radius: Style.space(6)
              color: pMouse.containsMouse ? root.hover : "transparent"
              Text { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: Style.space(18) }
              MouseArea {
                id: pMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.paletteOpen = false; root.reactRequested(parent.modelData) }
              }
            }
          }
        }
      }

      Avatar {
        visible: root.avatar && root.header
        anchors.left: parent.left
        anchors.top: parent.top
        userId: root.sender
        name: root.senderName
        mxc: root.senderAvatar
        service: root.service
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
            text: root.senderName + (root.via !== "" ? "  ·  " + root.via : "")
            color: root.nameColor
            font.family: root.fontFamily
            font.pixelSize: root.bodySize
            font.bold: true
          }
          Text {
            anchors.baseline: parent.children[0].baseline
            readonly property bool flag: root.roomEncrypted && !root.encrypted
            text: Qt.formatTime(new Date(root.ts), "HH:mm") + (root.edited ? "  (edited)" : "") + (flag ? "  󰌿 unencrypted" : "")
            color: flag ? Color.urgent : root.fg
            opacity: flag ? 0.8 : 0.45
            font.family: root.fontFamily
            font.pixelSize: root.captionSize
          }
        }

        // Quoted original, for replies
        Rectangle {
          visible: root.replyTo !== null && root.replyTo !== undefined
          anchors.right: root.bubbles && root.mine ? parent.right : undefined
          anchors.left: root.bubbles && root.mine ? undefined : parent.left
          width: Math.min(parent.width, Math.max(Style.space(160), quoteCol.implicitWidth + Style.space(24)))
          implicitHeight: visible ? quoteCol.implicitHeight + Style.space(12) : 0
          radius: Style.space(6)
          color: Util.alpha(root.fg, 0.06)
          Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 3; radius: 2; color: root.replyTo ? Qt.hsla(Format.hueFor(root.replyTo.sender) / 360, 0.6, 0.62, 1) : root.accent }
          Column {
            id: quoteCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)
            Text {
              text: root.replyTo ? root.replyTo.sender_name : ""
              color: root.replyTo ? Qt.hsla(Format.hueFor(root.replyTo.sender) / 360, 0.6, 0.62, 1) : root.fg
              font.family: root.fontFamily; font.pixelSize: root.captionSize; font.bold: true
            }
            Text {
              width: parent.width
              text: root.replyTo ? root.replyTo.body : ""
              color: root.fg; opacity: 0.75
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.Wrap
              font.family: root.fontFamily; font.pixelSize: root.captionSize
            }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.jumpRequested(root.replyTo.event_id) }
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
          // An attachment's body is its filename unless the sender added a caption.
          visible: root.deleted || !root.isAttachment || (root.attachment && !!root.attachment.caption)
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
              text: root.deleted ? "<i>Message deleted</i>"
                : root.msgtype === "unable_to_decrypt"
                ? "<i>󰌾 Unable to decrypt — this device did not have the key. It fills in once backup or another device shares it.</i>"
                : (root.isAttachment ? Format.linkify(root.attachment.caption || "", linkColor)
                  : (root.html !== "" ? Format.cleanHtml(root.html, linkColor) : Format.linkify(root.body, linkColor)))
              wrapMode: Text.Wrap
              opacity: root.msgtype === "unable_to_decrypt" || root.deleted ? 0.6 : 1
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

        // Link preview card
        Item {
          visible: root.linkPreviews && root.preview !== null && !!(root.preview.title || root.preview.description)
          width: parent.width
          implicitHeight: visible ? previewCard.implicitHeight : 0
          Rectangle {
            id: previewCard
            anchors.right: root.bubbles && root.mine ? parent.right : undefined
            anchors.left: root.bubbles && root.mine ? undefined : parent.left
            width: Math.min(root.bubbles ? parent.width * 0.78 : parent.width, Style.space(440))
            implicitHeight: Math.max(previewCol.implicitHeight + Style.space(20), previewThumb.visible ? previewThumb.height + Style.space(20) : 0)
            radius: Style.space(10)
            color: Util.alpha(root.fg, 0.06)
            border.width: 1
            border.color: Util.alpha(root.fg, 0.14)
            clip: true
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: Style.space(3); color: root.accent }
            Column {
              id: previewCol
              anchors.left: parent.left
              anchors.right: previewThumb.visible ? previewThumb.left : parent.right
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              Text {
                width: parent.width
                visible: root.preview && !!root.preview.site
                text: root.preview ? String(root.preview.site) : ""
                color: root.fg; opacity: 0.55
                elide: Text.ElideRight
                font.family: root.fontFamily; font.pixelSize: root.captionSize
              }
              Text {
                width: parent.width
                text: root.preview ? String(root.preview.title || root.firstUrl) : ""
                color: root.fg
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font.family: root.fontFamily; font.pixelSize: root.bodySize; font.bold: true
              }
              Text {
                width: parent.width
                visible: root.preview && !!root.preview.description
                text: root.preview ? String(root.preview.description) : ""
                color: root.fg; opacity: 0.78
                elide: Text.ElideRight
                maximumLineCount: 3
                wrapMode: Text.Wrap
                font.family: root.fontFamily; font.pixelSize: root.captionSize
              }
            }
            // Rounded-square thumbnail from the page's og:image.
            Item {
              id: previewThumb
              readonly property string key: root.preview && root.preview.image ? root.preview.image + "@320" : ""
              readonly property string path: key !== "" && root.service && root.service.avatars[key] ? root.service.avatars[key] : ""
              visible: path !== "" && previewImage.status === Image.Ready
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: Style.space(10)
              width: Style.space(72)
              height: Style.space(72)
              function fetch() { if (key !== "" && root.service) root.service.resolveAvatar(root.preview.image, 320) }
              onKeyChanged: fetch()
              Component.onCompleted: fetch()
              Image {
                id: previewImage
                anchors.fill: parent
                source: previewThumb.path !== "" ? "file://" + previewThumb.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 320
                sourceSize.height: 320
                visible: false
              }
              Rectangle { id: previewMask; anchors.fill: parent; radius: Style.space(8); visible: false; layer.enabled: true }
              MultiEffect { anchors.fill: parent; source: previewImage; maskEnabled: true; maskSource: previewMask }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Quickshell.execDetached(["omarchy-launch-browser", root.firstUrl])
            }
          }
        }

        // Thread summary under a root: click opens the thread
        Item {
          readonly property int replies: root.threadInfo ? Number(root.threadInfo.replies) || 0 : 0
          readonly property int unread: root.threadInfo ? Number(root.threadInfo.unread) || 0 : 0
          visible: !root.inThread && replies > 0
          width: parent.width
          implicitHeight: visible ? Style.space(26) : 0
          Rectangle {
            id: threadLine
            anchors.right: root.bubbles && root.mine ? parent.right : undefined
            anchors.left: root.bubbles && root.mine ? undefined : parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: threadRow.implicitWidth + Style.space(16)
            height: Style.space(24)
            radius: Style.space(6)
            color: threadMouse.containsMouse ? Util.alpha(root.accent, 0.18) : Util.alpha(root.accent, 0.08)
            Row {
              id: threadRow
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text { anchors.verticalCenter: parent.verticalCenter; text: "󰻞"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.parent.replies + (parent.parent.parent.replies === 1 ? " reply" : " replies")
                color: root.accent
                font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.threadInfo && !!root.threadInfo.latest_ts
                text: "· " + (root.threadInfo && root.threadInfo.latest_sender_name ? root.threadInfo.latest_sender_name + " " : "")
                  + (root.threadInfo && root.threadInfo.latest_ts ? Format.timeOf(Number(root.threadInfo.latest_ts)) : "")
                color: root.fg; opacity: 0.6
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
              }
              // Unread replies: a small accent pill
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.parent.parent.unread > 0
                width: threadNewText.implicitWidth + Style.space(12)
                height: Style.space(18)
                radius: height / 2
                color: root.accent
                Text {
                  id: threadNewText
                  anchors.centerIn: parent
                  text: parent.parent.parent.parent.unread + " new"
                  color: root.bg
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true
                }
              }
            }
            MouseArea { id: threadMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.threadRequested() }
          }
        }

        // Reactions
        Flow {
          width: parent.width
          spacing: Style.space(4)
          visible: root.reactions.length > 0
          layoutDirection: root.bubbles && root.mine ? Qt.RightToLeft : Qt.LeftToRight
          Repeater {
            model: root.reactions
            delegate: Rectangle {
              required property var modelData
              readonly property bool own: !!modelData.mine
              width: chipRow.implicitWidth + Style.space(14)
              height: Style.space(24)
              radius: height / 2
              color: own ? Util.alpha(root.accent, 0.18) : Util.alpha(root.fg, 0.08)
              border.width: 1
              border.color: own ? root.accent : Util.alpha(root.fg, 0.15)
              Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text { text: parent.parent.modelData.key; font.pixelSize: root.captionSize + 1 }
                Text { text: String(parent.parent.modelData.count); color: root.fg; font.family: root.fontFamily; font.pixelSize: root.captionSize; font.bold: parent.parent.own }
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reactRequested(parent.modelData.key)
                onEntered: chipTip.visible = true
                onExited: chipTip.visible = false
              }
              Rectangle {
                id: chipTip
                visible: false
                anchors.bottom: parent.top
                anchors.bottomMargin: 4
                anchors.left: parent.left
                width: chipTipText.implicitWidth + 12
                height: chipTipText.implicitHeight + 6
                radius: 4
                color: Color.tooltip.background
                border.color: Color.tooltip.border
                border.width: 1
                Text {
                  id: chipTipText
                  anchors.centerIn: parent
                  text: parent.parent.modelData.senders.map(function(u) { return u.name }).join(", ")
                  color: Color.tooltip.text
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }

        // Seen by: tiny avatars of others whose receipt is here
        Row {
          visible: root.readBy.length > 0
          anchors.right: parent.right
          spacing: -Style.space(4)
          Repeater {
            model: root.readBy.slice(0, 6)
            delegate: Avatar {
              required property var modelData
              size: Style.space(16)
              userId: modelData.id
              name: modelData.name
              fontFamily: root.fontFamily
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: seenTip.visible = true
                onExited: seenTip.visible = false
              }
            }
          }
          Text {
            visible: root.readBy.length > 6
            anchors.verticalCenter: parent.verticalCenter
            text: " +" + (root.readBy.length - 6)
            color: root.fg; opacity: 0.5
            font.family: root.fontFamily; font.pixelSize: root.captionSize - 2
          }
          Rectangle {
            id: seenTip
            visible: false
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            anchors.right: parent.right
            width: seenText.implicitWidth + 12
            height: seenText.implicitHeight + 6
            radius: 4
            color: Color.tooltip.background
            border.color: Color.tooltip.border
            border.width: 1
            Text {
              id: seenText
              anchors.centerIn: parent
              text: "Seen by " + root.readBy.map(function(u) { return u.name }).join(", ")
              color: Color.tooltip.text
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
          }
        }

        // Bubble style: time under your own bubbles on the first of a run,
        // and whenever the bubble was edited so the change is acknowledged
        Text {
          visible: root.bubbles && root.mine && (root.header || root.edited)
          anchors.right: parent.right
          text: Qt.formatTime(new Date(root.ts), "HH:mm") + (root.edited ? "  (edited)" : "") + (root.roomEncrypted && !root.encrypted ? "  󰌿" : "")
          color: root.roomEncrypted && !root.encrypted ? Color.urgent : root.fg
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: root.captionSize
        }
      }
    }
  }
}

import QtQuick
import QtMultimedia
import Quickshell
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// One message in the Yapper look: picture, name and time on the first of
// a run, then the body — text, image, file, voice note, an undecryptable
// or deleted marker, a link card — with reactions, the thread chip and
// read receipts underneath. Flat by default; `bubbles` puts your own
// messages on the right.
Item {
  id: root
  property var c: Palettes.fallback()
  property var service: null
  property string roomId: ""
  property string eventId: ""
  property string sender: ""
  property string senderName: ""
  property string senderAvatar: ""
  property string body: ""
  property string html: ""
  property string msgtype: "m.text"
  property var attachment: null
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
  property string via: ""
  property var reactions: []
  property var readBy: []
  property var threadInfo: null
  property bool inThread: false
  property bool isThreadRoot: false
  property bool bubbles: false
  property bool showAvatars: true
  property bool senderColors: true
  property real scale: 1.0
  signal replyRequested()
  signal editRequested()
  signal deleteRequested()
  signal reactRequested(string key)
  signal jumpRequested(string eventId)
  signal threadRequested()
  Ui { id: ui }

  readonly property bool isSystem: msgtype === "system"
  readonly property bool undecryptable: msgtype === "unable_to_decrypt"
  readonly property bool isAttachment: attachment !== null && attachment !== undefined
  readonly property bool isImage: isAttachment && attachment.kind === "image"
  readonly property bool isVoice: isAttachment && attachment.voice === true
  readonly property bool isFile: isAttachment && !isImage && !isVoice
  readonly property bool hasText: !deleted && !undecryptable && (isAttachment ? !!attachment.caption : body !== "")
  readonly property bool own: bubbles && mine
  readonly property bool showAvatar: showAvatars && !own && header
  readonly property real gutter: bubbles && mine ? 0 : (showAvatars ? ui.px(34) + ui.px(10) : 0)
  readonly property color senderColor: mine ? c.accent : (senderColors ? Palettes.colorOf(sender, c.light) : c.fg)
  readonly property real bodySize: ui.px(13.5) * scale
  readonly property string linkColor: c.accent
  // Room for the body: a bubble takes up to 74% of the row, flat text up
  // to 760 px. The bubble then shrinks to what its content needs.
  readonly property real maxContent: bubbles ? Math.max(ui.px(120), content.width * 0.74 - ui.px(24)) : Math.min(content.width, ui.px(760))
  readonly property real naturalWidth: {
    var w = ui.px(40)
    if (bodyText.visible) w = Math.max(w, bodyText.width)
    if (ownTime.visible) w = Math.max(w, ownTime.implicitWidth)
    if (quoteBox.visible) w = Math.max(w, Math.min(ui.px(420), Math.max(quoteName.implicitWidth, quoteBody.implicitWidth) + ui.px(11)))
    if (imageFrame.visible) w = Math.max(w, imageFrame.width)
    if (fileCard.visible) w = Math.max(w, fileCard.width)
    if (voiceCard.visible) w = Math.max(w, voiceCard.width)
    if (utdBox.visible) w = Math.max(w, utdBox.width)
    if (deletedRow.visible) w = Math.max(w, deletedRow.implicitWidth)
    if (previewCard.visible) w = Math.max(w, previewCard.width)
    return Math.min(w, maxContent)
  }

  // ---------- media ----------
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
  function openFull() {
    if (!root.service || root.fetching) return
    root.fetching = true
    root.service.download(root.roomId, root.eventId, false, function(r) {
      if (!root) return
      root.fetching = false
      if (r.ok) root.service.openPath(r.result.path)
      else root.fetchError = r.error || "Could not download"
    })
  }
  // Link previews: the first URL in a text message, once.
  property var preview: null
  property bool previewAsked: false
  readonly property string firstUrl: root.deleted || root.isAttachment ? "" : Format.firstUrl(root.body)
  function loadPreview() {
    if (!root.linkPreviews || root.previewAsked || root.firstUrl === "" || !root.service) return
    root.previewAsked = true
    root.service.preview(root.firstUrl, function(p) { if (root) root.preview = p })
  }
  onFirstUrlChanged: { previewAsked = false; preview = null; loadPreview() }
  onLinkPreviewsChanged: loadPreview()
  Component.onCompleted: { loadThumb(); loadPreview() }
  onEventIdChanged: { thumbPath = ""; loadThumb() }

  property bool paletteOpen: false
  readonly property var quickEmoji: ["👍", "❤️", "😂", "😮", "😢", "🎉", "🔥", "👀"]

  implicitHeight: column.implicitHeight

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 0

    // Where you left off
    Item {
      width: parent.width
      visible: root.newDivider
      height: visible ? ui.px(26) : 0
      Rectangle { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: newPill.left; anchors.rightMargin: ui.px(8); height: 1; color: root.c.accent; opacity: 0.6 }
      Rectangle {
        id: newPill
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: newText.implicitWidth + ui.px(12)
        height: ui.px(17)
        radius: ui.px(4)
        color: root.c.accent
        Text { id: newText; anchors.centerIn: parent; text: "NEW"; color: root.c.bg2; font.family: ui.mono; font.pixelSize: ui.f10; font.bold: true; font.letterSpacing: 1 }
      }
    }

    // Day separator
    Item {
      width: parent.width
      visible: root.dayLabel !== ""
      height: visible ? ui.px(40) : 0
      Rectangle { anchors.left: parent.left; anchors.right: dayText.left; anchors.rightMargin: ui.px(12); anchors.verticalCenter: parent.verticalCenter; height: 1; color: root.c.line }
      Text {
        id: dayText
        anchors.centerIn: parent
        text: root.dayLabel.toUpperCase()
        color: root.c.muted
        font.family: ui.mono; font.pixelSize: ui.f10; font.letterSpacing: 1
      }
      Rectangle { anchors.left: dayText.right; anchors.leftMargin: ui.px(12); anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 1; color: root.c.line }
    }

    // Membership and other quiet events
    Item {
      width: parent.width
      visible: root.isSystem
      height: visible ? sysText.implicitHeight + ui.px(8) : 0
      Row {
        anchors.left: parent.left
        anchors.leftMargin: ui.px(44)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(8)
        Icon { anchors.verticalCenter: parent.verticalCenter; name: "info"; size: ui.px(12); color: root.c.muted }
        Text {
          textFormat: Text.PlainText
          id: sysText
          width: parent.width - ui.px(20)
          text: root.body
          color: root.c.muted
          elide: Text.ElideRight
          font.family: ui.sans; font.pixelSize: ui.f12
        }
      }
    }

    // The message
    Item {
      id: row
      width: parent.width
      visible: !root.isSystem
      height: visible ? content.implicitHeight + (root.header ? ui.px(10) : ui.px(2)) : 0

      Rectangle {
        anchors.fill: parent
        radius: ui.px(7)
        color: root.highlighted ? root.c.sel : (rowMouse.containsMouse || actionsMouse.containsMouse || root.paletteOpen ? root.c.hover : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
      }
      MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

      Avatar {
        visible: root.showAvatar
        anchors.left: parent.left
        anchors.leftMargin: ui.px(10)
        anchors.top: parent.top
        anchors.topMargin: ui.px(7)
        service: root.service
        userId: root.sender
        name: root.senderName
        mxc: root.senderAvatar
        size: ui.px(34)
        fallbackColor: Palettes.colorOf(root.sender, root.c.light)
        initialColor: root.c.bg2
        fontFamily: ui.sans
      }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: ui.px(10) + root.gutter
        anchors.rightMargin: ui.px(10)
        anchors.top: parent.top
        anchors.topMargin: root.header ? ui.px(5) : ui.px(1)
        spacing: ui.px(3)

        // Name · via · time
        Row {
          visible: root.header && !root.own
          spacing: ui.px(8)
          Text {
            textFormat: Text.PlainText
            anchors.baseline: parent.bottom
            text: root.mine ? "You" : root.senderName
            color: root.senderColor
            font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold
          }
          Rectangle {
            visible: root.via !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: viaText.implicitWidth + ui.px(10)
            height: ui.px(16)
            radius: ui.px(4)
            color: root.c.chip
            Text { id: viaText; anchors.centerIn: parent; text: "via " + root.via; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(9.5); font.letterSpacing: 0.5 }
          }
          Text {
            anchors.baseline: parent.bottom
            text: Qt.formatTime(new Date(root.ts), "HH:mm")
            color: root.c.muted
            font.family: ui.mono; font.pixelSize: ui.px(10.5)
          }
          Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.roomEncrypted && !root.encrypted && !root.deleted
            name: "lock-key-open"; size: ui.px(11); color: root.c.warn
          }
        }

        // The block: transparent when flat, a bubble otherwise
        Item {
          width: parent.width
          height: bubble.height
          Rectangle {
            id: bubble
            anchors.right: root.own ? parent.right : undefined
            anchors.left: root.own ? undefined : parent.left
            width: root.bubbles ? root.naturalWidth + ui.px(24) : root.maxContent
            height: bubbleColumn.implicitHeight + (root.bubbles ? ui.px(16) : 0)
            radius: root.bubbles ? ui.px(12) : 0
            color: !root.bubbles ? "transparent" : (root.mine ? root.c.own : root.c.surface)
            border.width: root.bubbles && !root.mine ? 1 : 0
            border.color: root.c.line

            Column {
              id: bubbleColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: root.bubbles ? ui.px(8) : 0
              anchors.leftMargin: root.bubbles ? ui.px(12) : 0
              anchors.rightMargin: root.bubbles ? ui.px(12) : 0
              spacing: ui.px(7)

              // Bubble style keeps the time inside your own bubble
              Text {
                id: ownTime
                visible: root.own && root.header
                text: Qt.formatTime(new Date(root.ts), "HH:mm")
                color: root.c.muted
                font.family: ui.mono; font.pixelSize: ui.px(10.5)
              }

              // Reply quote
              Item {
                id: quoteBox
                visible: root.replyTo !== null && root.replyTo !== undefined
                width: parent.width
                height: visible ? quoteColumn.implicitHeight + ui.px(2) : 0
                readonly property color quoteColor: root.replyTo ? (root.replyTo.sender === (root.service ? root.service.userId : "") ? root.c.accent : Palettes.colorOf(root.replyTo.sender, root.c.light)) : root.c.line
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: ui.px(2); radius: 1; color: parent.quoteColor }
                Column {
                  id: quoteColumn
                  anchors.left: parent.left
                  anchors.leftMargin: ui.px(11)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: ui.px(1)
                  Text {
                    id: quoteName
                    text: root.replyTo ? root.replyTo.sender_name : ""
                    color: parent.parent.quoteColor
                    font.family: ui.sans; font.pixelSize: ui.f11; font.weight: Font.DemiBold
                  }
                  Text {
                    textFormat: Text.PlainText
                    id: quoteBody
                    width: Math.min(parent.width, ui.px(420))
                    text: root.replyTo ? Format.oneLine(root.replyTo.body) : ""
                    color: root.c.muted
                    elide: Text.ElideRight
                    font.family: ui.sans; font.pixelSize: ui.f12
                  }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.replyTo) root.jumpRequested(root.replyTo.event_id) }
              }

              // Text
              Text {
                id: bodyText
                visible: root.hasText
                width: root.bubbles ? Math.min(implicitWidth, root.maxContent) : root.maxContent
                textFormat: Text.RichText
                text: (root.isAttachment ? Format.linkify(root.attachment.caption || "", root.linkColor)
                  : (root.html !== "" ? Format.cleanHtml(root.html, root.linkColor) : Format.linkify(root.body, root.linkColor)))
                  + (root.edited ? " <font color=\"" + root.c.muted + "\" size=\"2\">(edited)</font>" : "")
                wrapMode: Text.Wrap
                color: root.mention ? root.c.warn : root.c.fg
                linkColor: root.linkColor
                lineHeight: 1.3
                font.family: ui.sans
                font.pixelSize: root.bodySize
                onLinkActivated: function(link) { Quickshell.execDetached(["omarchy-launch-browser", link]) }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor }
              }

              // Image
              Rectangle {
                id: imageFrame
                visible: root.isImage
                readonly property real maxW: Math.min(root.maxContent, ui.px(420))
                readonly property real srcW: root.isImage && root.attachment.width ? Number(root.attachment.width) : 4
                readonly property real srcH: root.isImage && root.attachment.height ? Number(root.attachment.height) : 3
                readonly property real ratio: Math.max(0.2, Math.min(3, srcH / srcW))
                width: Math.min(maxW, thumb.status === Image.Ready ? Math.max(ui.px(120), thumb.implicitWidth) : maxW)
                height: visible ? Math.min(ui.px(420), Math.round(width * ratio)) : 0
                radius: ui.px(7)
                color: root.c.surface
                border.width: 1
                border.color: root.c.line
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
                  spacing: ui.px(6)
                  Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "image"; size: ui.px(22); color: root.c.muted }
                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.fetchError !== "" ? root.fetchError : (root.attachment ? root.attachment.name : "")
                    color: root.c.muted
                    font.family: ui.mono; font.pixelSize: ui.px(10.5)
                  }
                }
                Rectangle {
                  anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                  height: imageCaption.implicitHeight + ui.px(10)
                  color: Qt.rgba(0, 0, 0, 0.55)
                  opacity: imageMouse.containsMouse ? 1 : 0
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                  Text {
                    textFormat: Text.PlainText
                    id: imageCaption
                    anchors.left: parent.left; anchors.right: parent.right; anchors.margins: ui.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.attachment ? root.attachment.name + (root.attachment.size ? "  ·  " + Format.fileSize(root.attachment.size) : "") : ""
                    color: "#ffffff"
                    elide: Text.ElideRight
                    font.family: ui.mono; font.pixelSize: ui.px(10.5)
                  }
                }
                MouseArea { id: imageMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openFull() }
              }

              // File
              Rectangle {
                id: fileCard
                visible: root.isFile
                width: Math.min(root.maxContent, ui.px(360))
                height: visible ? ui.px(50) : 0
                radius: ui.px(7)
                color: root.c.bg2
                border.width: 1
                border.color: root.c.line
                Icon {
                  id: fileIcon
                  anchors.left: parent.left
                  anchors.leftMargin: ui.px(11)
                  anchors.verticalCenter: parent.verticalCenter
                  name: root.attachment && root.attachment.kind === "video" ? "film-strip" : (root.attachment && root.attachment.kind === "audio" ? "music-notes" : "file")
                  size: ui.px(20)
                  color: root.c.accent
                }
                Column {
                  anchors.left: fileIcon.right
                  anchors.leftMargin: ui.px(11)
                  anchors.right: openPill.left
                  anchors.rightMargin: ui.px(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: ui.px(1)
                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.attachment ? root.attachment.name : ""
                    color: root.c.fg
                    elide: Text.ElideMiddle
                    font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.Medium
                  }
                  Text {
                    width: parent.width
                    text: root.fetchError !== "" ? root.fetchError
                      : root.attachment ? ((root.attachment.size ? Format.fileSize(root.attachment.size) : "") + (root.attachment.mime ? "  ·  " + root.attachment.mime : "")) : ""
                    color: root.fetchError !== "" ? root.c.bad : root.c.muted
                    elide: Text.ElideRight
                    font.family: ui.mono; font.pixelSize: ui.px(10.5)
                  }
                }
                Rectangle {
                  id: openPill
                  anchors.right: parent.right
                  anchors.rightMargin: ui.px(10)
                  anchors.verticalCenter: parent.verticalCenter
                  width: openText.implicitWidth + ui.px(22)
                  height: ui.px(26)
                  radius: height / 2
                  color: openMouse.containsMouse ? root.c.hover : "transparent"
                  border.width: 1
                  border.color: root.c.line
                  Text { id: openText; anchors.centerIn: parent; text: root.fetching ? "…" : "Open"; color: openMouse.containsMouse ? root.c.accent : root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
                  MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openFull() }
                }
              }

              // Voice note
              Item {
                id: voiceCard
                visible: root.isVoice
                width: Math.min(root.maxContent, ui.px(320))
                height: visible ? ui.px(32) : 0
                readonly property int durationMs: root.attachment && root.attachment.duration_ms ? Number(root.attachment.duration_ms) : 0
                readonly property var bars: {
                  // 40 bars from however many points the sender gave us.
                  var w = root.attachment && root.attachment.waveform ? root.attachment.waveform : []
                  var out = []
                  if (w.length === 0) { for (var i = 0; i < 40; i++) out.push(0.35); return out }
                  for (var b = 0; b < 40; b++) {
                    var from = Math.floor(b * w.length / 40), to = Math.max(from + 1, Math.floor((b + 1) * w.length / 40))
                    var peak = 0
                    for (var j = from; j < to; j++) peak = Math.max(peak, Number(w[j]) || 0)
                    out.push(Math.max(0.12, Math.min(1, peak / 1024)))
                  }
                  return out
                }
                property string path: ""
                property bool loading: false
                readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
                readonly property real progress: player.duration > 0 ? player.position / player.duration : 0
                function toggle() {
                  if (playing) { player.pause(); return }
                  if (path !== "") { player.play(); return }
                  if (loading || !root.service) return
                  loading = true
                  root.service.download(root.roomId, root.eventId, false, function(r) {
                    if (!voiceCard) return
                    voiceCard.loading = false
                    if (!r.ok) { root.fetchError = r.error || "Could not download"; return }
                    voiceCard.path = r.result.path
                    player.source = "file://" + r.result.path
                    player.play()
                  })
                }
                MediaDevices { id: outputs }
                MediaPlayer {
                  id: player
                  audioOutput: AudioOutput {
                    volume: root.service ? root.service.voiceVolume : 1
                    // The chosen speaker, when it is present; else the default.
                    device: {
                      var want = root.service ? root.service.voiceOutput : ""
                      for (var i = 0; want !== "" && i < outputs.audioOutputs.length; i++)
                        if (outputs.audioOutputs[i].id === want) return outputs.audioOutputs[i]
                      return outputs.defaultAudioOutput
                    }
                  }
                  onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) { player.stop(); player.position = 0 }
                  onErrorOccurred: function(e, msg) { root.fetchError = "Could not play: " + msg }
                }
                Rectangle {
                  id: playButton
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: ui.px(32); height: width; radius: width / 2
                  color: playMouse.containsMouse ? Qt.lighter(root.c.accent, 1.12) : root.c.accent
                  Icon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: voiceCard.playing ? 0 : 1
                    name: voiceCard.loading ? "dots-three" : (voiceCard.playing ? "pause" : "play")
                    weight: "fill"
                    size: ui.px(14)
                    color: root.c.bg2
                  }
                  MouseArea { id: playMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: voiceCard.toggle() }
                }
                Item {
                  id: waveArea
                  anchors.left: playButton.right
                  anchors.leftMargin: ui.px(11)
                  anchors.right: durationLabel.left
                  anchors.rightMargin: ui.px(11)
                  anchors.verticalCenter: parent.verticalCenter
                  height: ui.px(28)
                  Row {
                    anchors.fill: parent
                    spacing: Math.max(1, (waveArea.width - 40 * ui.px(2.5)) / 39)
                    Repeater {
                      model: voiceCard.bars
                      delegate: Rectangle {
                        required property real modelData
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: ui.px(2.5)
                        height: Math.max(ui.px(3), waveArea.height * modelData)
                        radius: ui.px(2)
                        color: index / 40 < voiceCard.progress ? root.c.accent : (root.c.light ? Qt.rgba(0.3, 0.31, 0.41, 0.35) : Qt.rgba(1, 1, 1, 0.28))
                      }
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                      if (voiceCard.path === "") { voiceCard.toggle(); return }
                      player.position = Math.floor(mouse.x / width * player.duration)
                      if (!voiceCard.playing) player.play()
                    }
                  }
                }
                Text {
                  id: durationLabel
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: (voiceCard.playing || player.position > 0 ? Format.clock(player.position / 1000) + " / " : "") + Format.clock(voiceCard.durationMs / 1000)
                  color: root.c.muted
                  font.family: ui.mono; font.pixelSize: ui.f11
                }
              }

              // Unable to decrypt
              Rectangle {
                id: utdBox
                visible: root.undecryptable && !root.deleted
                width: Math.min(root.maxContent, utdRow.implicitWidth + ui.px(22))
                height: visible ? ui.px(38) : 0
                radius: ui.px(7)
                color: root.c.chip
                border.width: 1
                border.color: root.c.line
                Row {
                  id: utdRow
                  anchors.left: parent.left
                  anchors.leftMargin: ui.px(11)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: ui.px(9)
                  Icon { anchors.verticalCenter: parent.verticalCenter; name: "lock-key-open"; size: ui.px(16); color: root.c.warn }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Unable to decrypt — waiting for the key from another device."
                    color: root.c.muted
                    font.family: ui.sans; font.pixelSize: ui.px(12.5)
                  }
                }
              }

              // Deleted
              Row {
                id: deletedRow
                visible: root.deleted
                spacing: ui.px(8)
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "trash"; size: ui.px(13); color: root.c.muted }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Message deleted"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.italic: true }
              }

              // Link card
              Rectangle {
                id: previewCard
                visible: root.linkPreviews && root.preview !== null && root.preview !== undefined && !!(root.preview.title || root.preview.description)
                width: Math.min(root.maxContent, ui.px(440))
                height: visible ? Math.max(previewColumn.implicitHeight + ui.px(18), ui.px(64)) : 0
                radius: ui.px(7)
                color: root.c.bg2
                border.width: 1
                border.color: root.c.line
                clip: true
                readonly property string imageKey: root.preview && root.preview.image ? root.preview.image + "@320" : ""
                readonly property string imagePath: imageKey !== "" && root.service && root.service.avatars[imageKey] ? root.service.avatars[imageKey] : ""
                onImageKeyChanged: if (imageKey !== "" && root.service) root.service.resolveAvatar(root.preview.image, 320)
                Rectangle {
                  id: previewSide
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: ui.px(74)
                  color: root.c.surface
                  Icon { anchors.centerIn: parent; name: "link"; size: ui.px(20); color: root.c.muted; visible: previewImage.status !== Image.Ready }
                  Image {
                    id: previewImage
                    anchors.fill: parent
                    source: previewCard.imagePath !== "" ? "file://" + previewCard.imagePath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 320
                  }
                }
                Column {
                  id: previewColumn
                  anchors.left: previewSide.right
                  anchors.leftMargin: ui.px(11)
                  anchors.right: parent.right
                  anchors.rightMargin: ui.px(11)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: ui.px(3)
                  Text {
                    textFormat: Text.PlainText
                    visible: text !== ""
                    width: parent.width
                    text: root.preview && root.preview.site ? String(root.preview.site) : ""
                    color: root.c.muted; elide: Text.ElideRight
                    font.family: ui.mono; font.pixelSize: ui.f10; font.letterSpacing: 0.4
                  }
                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.preview ? String(root.preview.title || root.firstUrl) : ""
                    color: root.c.accent; elide: Text.ElideRight
                    font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.DemiBold
                  }
                  Text {
                    textFormat: Text.PlainText
                    visible: text !== ""
                    width: parent.width
                    text: root.preview && root.preview.description ? String(root.preview.description) : ""
                    color: root.c.muted
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    lineHeight: 1.2
                    font.family: ui.sans; font.pixelSize: ui.f11
                  }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["omarchy-launch-browser", root.firstUrl]) }
              }
            }
          }
        }

        // Reactions
        Flow {
          width: parent.width
          visible: root.reactions.length > 0
          spacing: ui.px(5)
          layoutDirection: root.own ? Qt.RightToLeft : Qt.LeftToRight
          Repeater {
            model: root.reactions
            delegate: Rectangle {
              required property var modelData
              readonly property bool ownReaction: !!modelData.mine
              width: reactionRow.implicitWidth + ui.px(18)
              height: ui.px(24)
              radius: height / 2
              color: ownReaction ? root.c.sel : "transparent"
              border.width: 1
              border.color: ownReaction || reactionMouse.containsMouse ? root.c.accent : root.c.line
              Row {
                id: reactionRow
                anchors.centerIn: parent
                spacing: ui.px(5)
                Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: parent.parent.modelData.key; font.pixelSize: ui.f12 }
                Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: String(parent.parent.modelData.count); color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
              }
              MouseArea {
                id: reactionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reactRequested(parent.modelData.key)
                onContainsMouseChanged: reactionTip.visible = containsMouse
              }
              Rectangle {
                id: reactionTip
                visible: false
                anchors.bottom: parent.top
                anchors.bottomMargin: ui.px(4)
                anchors.left: parent.left
                width: reactionTipText.implicitWidth + ui.px(14)
                height: ui.px(22)
                radius: ui.px(5)
                color: root.c.surface
                border.width: 1
                border.color: root.c.line
                z: 20
                Text { textFormat: Text.PlainText; id: reactionTipText; anchors.centerIn: parent; text: parent.parent.modelData.senders.map(function(u) { return u.name }).join(", "); color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f11 }
              }
            }
          }
          Rectangle {
            width: ui.px(28)
            height: ui.px(23)
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: addMouse.containsMouse ? root.c.accent : root.c.line
            Icon { anchors.centerIn: parent; name: "smiley-sticker"; size: ui.px(12); color: addMouse.containsMouse ? root.c.accent : root.c.muted }
            MouseArea { id: addMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.paletteOpen = !root.paletteOpen }
          }
        }

        // Thread chip
        Rectangle {
          visible: !root.inThread && root.threadInfo !== null && root.threadInfo !== undefined && Number(root.threadInfo.replies) > 0
          width: threadRow.implicitWidth + ui.px(20)
          height: visible ? ui.px(29) : 0
          radius: height / 2
          color: threadMouse.containsMouse ? root.c.hover : "transparent"
          border.width: 1
          border.color: threadMouse.containsMouse ? root.c.accent : root.c.line
          readonly property int unread: root.threadInfo ? Number(root.threadInfo.unread) || 0 : 0
          Row {
            id: threadRow
            anchors.centerIn: parent
            spacing: ui.px(8)
            Avatar {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.threadInfo && !!root.threadInfo.latest_sender
              service: root.service
              userId: root.threadInfo && root.threadInfo.latest_sender ? root.threadInfo.latest_sender : ""
              name: root.threadInfo && root.threadInfo.latest_sender_name ? root.threadInfo.latest_sender_name : ""
              size: ui.px(19)
              fallbackColor: Palettes.colorOf(userId, root.c.light)
              initialColor: root.c.bg2
              fontFamily: ui.sans
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.threadInfo ? root.threadInfo.replies + (Number(root.threadInfo.replies) === 1 ? " reply" : " replies") : ""
              color: root.c.accent
              font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.Medium
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: text !== ""
              text: root.threadInfo && root.threadInfo.latest_ts ? (root.threadInfo.latest_sender_name ? root.threadInfo.latest_sender_name + " · " : "") + Format.timeOf(Number(root.threadInfo.latest_ts)) : ""
              color: root.c.muted
              font.family: ui.sans; font.pixelSize: ui.f11
            }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              visible: parent.parent.unread > 0
              width: threadNewText.implicitWidth + ui.px(10)
              height: ui.px(17)
              radius: height / 2
              color: root.c.accent
              Text { id: threadNewText; anchors.centerIn: parent; text: parent.parent.parent.unread + " new"; color: root.c.bg2; font.family: ui.mono; font.pixelSize: ui.f10; font.bold: true }
            }
          }
          MouseArea { id: threadMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.threadRequested() }
        }

        // Read by
        Item {
          visible: root.readBy.length > 0
          width: parent.width
          height: visible ? ui.px(17) : 0
          Row {
            id: readRow
            anchors.right: root.own ? parent.right : undefined
            anchors.left: root.own ? undefined : parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: ui.px(4)
            Repeater {
              model: root.readBy.slice(0, 6)
              delegate: Avatar {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                service: root.service
                userId: modelData.id
                name: modelData.name
                size: ui.px(15)
                fallbackColor: Palettes.colorOf(modelData.id, root.c.light)
                initialColor: root.c.bg2
                fontFamily: ui.sans
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: (root.readBy.length > 6 ? "+" + (root.readBy.length - 6) + " " : "") + "read"
              color: root.c.muted
              font.family: ui.sans; font.pixelSize: ui.px(10.5)
            }
          }
          // Hover anywhere on the receipts for the names (outside the Row:
          // a Row child cannot anchor horizontally).
          MouseArea {
            anchors.right: root.own ? parent.right : undefined
            anchors.left: root.own ? undefined : parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: readRow.implicitWidth
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: readTip.visible = containsMouse
          }
          Rectangle {
            id: readTip
            visible: false
            anchors.bottom: parent.top
            anchors.bottomMargin: ui.px(2)
            anchors.left: root.own ? undefined : parent.left
            anchors.right: root.own ? parent.right : undefined
            width: readTipText.implicitWidth + ui.px(14)
            height: ui.px(22)
            radius: ui.px(5)
            color: root.c.surface
            border.width: 1
            border.color: root.c.line
            z: 20
            Text { textFormat: Text.PlainText; id: readTipText; anchors.centerIn: parent; text: "Seen by " + root.readBy.map(function(u) { return u.name }).join(", "); color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f11 }
          }
        }
      }

      // Hover actions
      Rectangle {
        id: actions
        visible: (rowMouse.containsMouse || actionsMouse.containsMouse || root.paletteOpen) && !root.undecryptable && !root.deleted
        anchors.right: parent.right
        anchors.rightMargin: ui.px(10)
        anchors.top: parent.top
        anchors.topMargin: -ui.px(12)
        z: 5
        width: actionsRow.implicitWidth + ui.px(8)
        height: ui.px(30)
        radius: ui.px(8)
        color: root.c.bg2
        border.width: 1
        border.color: root.c.line
        MouseArea { id: actionsMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        Row {
          id: actionsRow
          anchors.centerIn: parent
          spacing: ui.px(2)
          Repeater {
            model: {
              var a = [{ icon: "smiley", tip: "React", act: "react" }, { icon: "arrow-bend-up-left", tip: "Reply", act: "reply" }]
              if (!root.inThread) a.push({ icon: "tree-structure", tip: "Reply in thread", act: "thread" })
              if (root.canEdit) a.push({ icon: "pencil-simple", tip: "Edit", act: "edit" })
              if (root.canDelete) a.push({ icon: "trash", tip: "Delete", act: "delete" })
              return a
            }
            delegate: Rectangle {
              required property var modelData
              width: ui.px(26); height: ui.px(26)
              radius: ui.px(6)
              color: actionMouse.containsMouse ? root.c.hover : "transparent"
              Icon { anchors.centerIn: parent; name: parent.modelData.icon; size: ui.px(15); color: actionMouse.containsMouse ? (parent.modelData.act === "delete" ? root.c.bad : root.c.accent) : root.c.muted }
              MouseArea {
                id: actionMouse
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

      // Quick reactions
      Rectangle {
        visible: root.paletteOpen
        anchors.right: parent.right
        anchors.rightMargin: ui.px(10)
        anchors.top: parent.top
        anchors.topMargin: ui.px(20)
        z: 6
        width: paletteRow.implicitWidth + ui.px(12)
        height: ui.px(40)
        radius: ui.px(9)
        color: root.c.bg2
        border.width: 1
        border.color: root.c.line
        Row {
          id: paletteRow
          anchors.centerIn: parent
          spacing: ui.px(2)
          Repeater {
            model: root.quickEmoji
            delegate: Rectangle {
              required property string modelData
              width: ui.px(32); height: ui.px(32)
              radius: ui.px(7)
              color: paletteMouse.containsMouse ? root.c.hover : "transparent"
              Text { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: ui.px(18) }
              MouseArea {
                id: paletteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.paletteOpen = false; root.reactRequested(parent.modelData) }
              }
            }
          }
        }
      }
    }
  }
}

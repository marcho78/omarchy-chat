import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// One room in the Yapper look: the timeline, who is typing, and the
// composer with its hint row. Set `room` with open() to show it; clear
// it with close(). The behaviour lives in the shared RoomSession; this
// file only draws.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string viewId: "room"
  Ui { id: ui }

  property alias room: session.room
  readonly property string roomId: session.roomId
  readonly property string roomName: session.roomName
  readonly property bool encrypted: session.encrypted
  readonly property bool busy: session.busy
  readonly property string errorText: session.errorText
  readonly property string threadRoot: session.threadRoot
  readonly property bool inThread: session.inThread
  readonly property bool hasTextFocus: composer.hasFocus || recordStrip.activeFocus
  readonly property bool hasDraft: composer.text.trim() !== ""

  signal roomLeft()
  signal threadRequested(string eventId)
  signal closeRequested()

  function open(r) { session.open(r) }
  function openAt(r, eventId) { session.openAt(r, eventId) }
  function openThread(r, rootId) { session.openThread(r, rootId) }
  function close() { session.close() }
  function jumpTo(eventId) { session.jumpTo(eventId) }
  function focusComposer() { composer.forceActiveFocus() }
  function leave() { session.leave() }

  RoomSession {
    id: session
    service: root.service
    viewId: root.viewId
    composer: composer
    viewVisible: root.visible
    atEnd: msgList.atYEnd || msgList.contentHeight <= msgList.height
    onRoomLeft: root.roomLeft()
    onCloseRequested: root.closeRequested()
    onAnchorEnd: root.snapToEnd()
    onReveal: function(index, mode) { msgList.positionViewAtIndex(index, mode === 0 ? ListView.Beginning : ListView.Center) }
    onPrependStarted: { msgList.keptHeight = msgList.contentHeight; msgList.keptY = msgList.contentY }
    onPrependFinished: Qt.callLater(function() { msgList.contentY = msgList.keptY + (msgList.contentHeight - msgList.keptHeight) })
    onFocusComposerRequested: composer.forceActiveFocus()
    onFocusRecordingRequested: recordStrip.forceActiveFocus()
  }

  // Delegates load lazily (images, wrapped text), so a single
  // positionViewAtEnd lands short. Re-anchor a few times while rows
  // settle, and stop the moment the user scrolls away.
  function snapToEnd() { msgList.positionViewAtEnd(); settle.restart() }
  Timer {
    id: settle
    interval: 120
    repeat: true
    property int ticks: 0
    onRunningChanged: if (running) ticks = 0
    onTriggered: {
      if (!session.stickToEnd || msgList.dragging || msgList.flicking) { stop(); return }
      msgList.positionViewAtEnd()
      session.maybeMarkRead()
      if (++ticks >= 12) stop()
    }
  }

  component Kbd: Rectangle {
    property string label: ""
    width: kbdText.implicitWidth + ui.px(8)
    height: ui.px(16)
    radius: ui.px(4)
    color: "transparent"
    border.width: 1
    border.color: root.c.line
    Text { id: kbdText; anchors.centerIn: parent; text: parent.label; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
  }
  component RoundButton: Rectangle {
    property string icon: ""
    property bool primary: false
    property string tooltip: ""
    signal clicked()
    width: ui.px(32); height: ui.px(32); radius: width / 2
    color: primary ? (roundMouse.containsMouse ? Qt.lighter(root.c.accent, 1.12) : root.c.accent) : (roundMouse.containsMouse ? root.c.hover : "transparent")
    border.width: primary ? 0 : 1
    border.color: root.c.line
    Icon { anchors.centerIn: parent; name: parent.icon; weight: parent.primary ? "fill" : "regular"; size: ui.px(14); color: parent.primary ? root.c.bg2 : root.c.fg }
    MouseArea {
      id: roundMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
      onContainsMouseChanged: { if (!root.tips || parent.tooltip === "") return; if (containsMouse) root.tips.show(parent, parent.tooltip); else root.tips.hide(parent) }
    }
  }

  // ---------- timeline ----------
  ListView {
    id: msgList
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: typingRow.top
    anchors.leftMargin: ui.px(4)
    anchors.rightMargin: ui.px(4)
    anchors.topMargin: ui.px(14)
    // Where the list stood before older rows were inserted above it.
    property real keptHeight: 0
    property real keptY: 0
    clip: true
    spacing: 0
    model: session.model
    cacheBuffer: 2000
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    onContentYChanged: if (contentY <= originY + ui.px(40) && session.hasOlder && !session.loadingOlder && count > 0) session.loadOlder()
    onDraggingChanged: if (dragging) session.stickToEnd = false
    onFlickingChanged: if (flicking && !atYEnd) session.stickToEnd = false
    onAtYEndChanged: if (atYEnd) session.stickToEnd = true
    onHeightChanged: if (session.stickToEnd) Qt.callLater(root.snapToEnd)

    header: Item {
      width: msgList.width
      height: session.count > 0 ? ui.px(44) : 0
      Rectangle {
        anchors.centerIn: parent
        visible: session.count > 0
        width: earlierText.implicitWidth + ui.px(28)
        height: ui.px(27)
        radius: height / 2
        color: earlierMouse.containsMouse && session.hasOlder ? root.c.hover : "transparent"
        border.width: session.hasOlder || session.loadingOlder ? 1 : 0
        border.color: root.c.line
        Text {
          id: earlierText
          anchors.centerIn: parent
          text: session.loadingOlder ? "Loading…" : (session.hasOlder ? "Load earlier" : (session.inThread ? "The thread starts here" : "You have reached the start of the room"))
          color: earlierMouse.containsMouse && session.hasOlder ? root.c.accent : root.c.muted
          font.family: ui.sans; font.pixelSize: ui.f11
        }
        MouseArea { id: earlierMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: session.hasOlder ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: session.loadOlder() }
      }
    }

    delegate: MessageRow {
      required property var model
      required property int index
      width: msgList.width
      c: root.c
      service: root.service
      roomId: root.roomId
      eventId: model.eventId
      sender: model.sender
      senderName: model.senderName
      senderAvatar: model.senderAvatar
      body: model.body
      html: model.html
      msgtype: model.msgtype
      attachment: model.attachmentJson !== "" ? JSON.parse(model.attachmentJson) : null
      ts: model.ts
      mine: model.mine
      encrypted: model.encrypted
      roomEncrypted: root.encrypted
      header: model.header
      dayLabel: model.dayLabel
      newDivider: model.newDivider
      replyTo: model.replyJson !== "" ? JSON.parse(model.replyJson) : null
      edited: model.edited
      deleted: model.deleted
      mention: model.mention
      via: model.via
      linkPreviews: root.service ? root.service.linkPreviews : true
      reactions: JSON.parse(model.reactionsJson)
      readBy: JSON.parse(model.readByJson)
      highlighted: index === session.flashIndex
      canEdit: model.mine && !model.attachmentJson && !model.deleted
      canDelete: model.mine && !model.deleted
      threadInfo: model.threadJson !== "" ? JSON.parse(model.threadJson) : null
      inThread: root.inThread
      isThreadRoot: root.inThread && model.eventId === root.threadRoot
      bubbles: root.service ? root.service.bubbles : false
      showAvatars: root.service ? root.service.showAvatars : true
      senderColors: root.service ? root.service.senderColors : true
      scale: root.service ? root.service.fontScale : 1.0
      onReactRequested: function(key) { session.toggleReaction(model.eventId, key) }
      onReplyRequested: session.startReply({ event_id: model.eventId, sender_name: model.senderName, body: model.body })
      onEditRequested: session.startEdit({ event_id: model.eventId, body: model.body })
      onDeleteRequested: session.confirmDelete = { event_id: model.eventId, body: model.body }
      onJumpRequested: function(id) { session.jumpTo(id) }
      onThreadRequested: root.threadRequested(model.eventId)
    }
  }

  // "N new messages" pill
  Rectangle {
    visible: session.pendingNew > 0 && !session.atEnd
    anchors.horizontalCenter: msgList.horizontalCenter
    anchors.bottom: msgList.bottom
    anchors.bottomMargin: ui.px(10)
    z: 3
    width: pillRow.implicitWidth + ui.px(24)
    height: ui.px(30)
    radius: height / 2
    color: root.c.accent
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: ui.px(6)
      Icon { anchors.verticalCenter: parent.verticalCenter; name: "arrow-down"; weight: "bold"; size: ui.px(12); color: root.c.bg2 }
      Text { anchors.verticalCenter: parent.verticalCenter; text: session.pendingNew + " new message" + (session.pendingNew === 1 ? "" : "s"); color: root.c.bg2; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.DemiBold }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: session.jumpToNew() }
  }

  // Who is typing
  Item {
    id: typingRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: composerArea.top
    height: session.typingText !== "" ? ui.px(22) : 0
    clip: true
    Row {
      anchors.left: parent.left
      anchors.leftMargin: ui.px(18)
      anchors.verticalCenter: parent.verticalCenter
      spacing: ui.px(8)
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(2.5)
        Repeater {
          model: 3
          delegate: Rectangle {
            required property int index
            width: ui.px(4); height: ui.px(4); radius: width / 2
            color: root.c.accent
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: session.typingText !== ""
              PauseAnimation { duration: index * 180 }
              NumberAnimation { to: 1; duration: 360 }
              NumberAnimation { to: 0.3; duration: 360 }
              PauseAnimation { duration: (2 - index) * 180 }
            }
          }
        }
      }
      Text { anchors.verticalCenter: parent.verticalCenter; text: session.typingText + "…"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
    }
  }

  // ---------- composer ----------
  Column {
    id: composerArea
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: ui.px(14)
    anchors.rightMargin: ui.px(14)
    anchors.bottomMargin: ui.px(14)
    spacing: ui.px(6)

    // Delete confirmation
    Rectangle {
      width: parent.width
      visible: session.confirmDelete !== null
      height: visible ? ui.px(52) : 0
      radius: ui.px(10)
      color: root.c.bg2
      border.width: 1
      border.color: root.c.bad
      Column {
        anchors.left: parent.left
        anchors.leftMargin: ui.px(13)
        anchors.right: deleteButtons.left
        anchors.rightMargin: ui.px(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(2)
        Text { text: "Delete this message?"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.DemiBold }
        Text { width: parent.width; text: session.confirmDelete ? Format.oneLine(session.confirmDelete.body || "(attachment)") : ""; color: root.c.muted; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.f11 }
      }
      Row {
        id: deleteButtons
        anchors.right: parent.right
        anchors.rightMargin: ui.px(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(6)
        Rectangle {
          width: deleteText.implicitWidth + ui.px(22); height: ui.px(30); radius: ui.px(7)
          color: deleteMouse.containsMouse ? Qt.lighter(root.c.bad, 1.1) : root.c.bad
          Text { id: deleteText; anchors.centerIn: parent; text: "Delete"; color: root.c.bg2; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.DemiBold }
          MouseArea { id: deleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: session.deleteMessage(session.confirmDelete.event_id) }
        }
        Rectangle {
          width: keepText.implicitWidth + ui.px(22); height: ui.px(30); radius: ui.px(7)
          color: keepMouse.containsMouse ? root.c.hover : "transparent"
          border.width: 1; border.color: root.c.line
          Text { id: keepText; anchors.centerIn: parent; text: "Keep"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12 }
          MouseArea { id: keepMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: session.confirmDelete = null }
        }
      }
    }

    Text {
      width: parent.width
      visible: session.errorText !== ""
      text: session.errorText
      color: root.c.bad
      wrapMode: Text.WordWrap
      font.family: ui.sans; font.pixelSize: ui.f11
    }

    // Recording: takes the composer's place
    Rectangle {
      id: recordStrip
      width: parent.width
      visible: session.recordingHere
      height: visible ? ui.px(56) : 0
      radius: ui.px(10)
      color: root.c.bg2
      border.width: 1
      border.color: root.c.bad
      // The composer is hidden meanwhile, so the strip takes the keys.
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { event.accepted = true; session.stopVoice(true) }
        else if (event.key === Qt.Key_Escape) { event.accepted = true; session.stopVoice(false) }
      }
      Row {
        anchors.left: parent.left
        anchors.leftMargin: ui.px(13)
        anchors.right: recordButtons.left
        anchors.rightMargin: ui.px(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(12)
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: ui.px(9); height: ui.px(9); radius: width / 2
          color: root.c.bad
          SequentialAnimation on scale {
            loops: Animation.Infinite
            running: session.recordingHere
            NumberAnimation { to: 1.4; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
          }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: Format.clock(root.service ? root.service.recordSeconds : 0); color: root.c.fg; font.family: ui.mono; font.pixelSize: ui.f13 }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Recording a voice message"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Enter sends · Esc discards"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
      }
      Row {
        id: recordButtons
        anchors.right: parent.right
        anchors.rightMargin: ui.px(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(8)
        RoundButton { icon: "x"; tooltip: "Discard"; onClicked: session.stopVoice(false) }
        RoundButton { icon: "paper-plane-right"; primary: true; tooltip: "Send the voice message"; onClicked: session.stopVoice(true) }
      }
    }

    // The frame
    Item {
      width: parent.width
      visible: !session.recordingHere
      height: frame.height

      // Emoji completion, above the frame
      Rectangle {
        id: emojiPop
        visible: session.emojiHits.length > 0
        anchors.left: parent.left
        anchors.bottom: frame.top
        anchors.bottomMargin: ui.px(8)
        z: 4
        width: Math.max(ui.px(220), emojiColumn.implicitWidth + ui.px(10))
        height: emojiColumn.implicitHeight + ui.px(10)
        radius: ui.px(9)
        color: root.c.bg2
        border.width: 1
        border.color: root.c.line
        Column {
          id: emojiColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: ui.px(5)
          spacing: ui.px(1)
          Repeater {
            model: session.emojiHits
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: parent.width
              height: ui.px(30)
              radius: ui.px(6)
              color: index === session.emojiIndex ? root.c.hover : (hitMouse.containsMouse ? root.c.chip : "transparent")
              Row {
                anchors.left: parent.left
                anchors.leftMargin: ui.px(9)
                anchors.verticalCenter: parent.verticalCenter
                spacing: ui.px(10)
                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.modelData.e; font.pixelSize: ui.px(16) }
                Text { anchors.verticalCenter: parent.verticalCenter; text: ":" + parent.parent.modelData.k; color: root.c.fg; font.family: ui.mono; font.pixelSize: ui.f11 }
              }
              MouseArea { id: hitMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: session.insertEmoji(index) }
            }
          }
          Item { width: parent.width; height: ui.px(4) }
          Rectangle { width: parent.width; height: 1; color: root.c.line }
          Text { leftPadding: ui.px(9); topPadding: ui.px(4); text: "Tab or Enter inserts"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) }
        }
      }

      Rectangle {
        id: frame
        width: parent.width
        height: frameColumn.implicitHeight
        radius: ui.px(10)
        color: root.c.bg2
        border.width: 1
        border.color: composer.hasFocus || root.hasDraft ? root.c.accent : root.c.line
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Column {
          id: frameColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top

          // Replying / editing
          Item {
            width: parent.width
            visible: session.replyTo !== null || session.editing !== null
            height: visible ? ui.px(34) : 0
            Row {
              anchors.left: parent.left
              anchors.leftMargin: ui.px(11)
              anchors.right: stripClose.left
              anchors.rightMargin: ui.px(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: ui.px(9)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: session.editing ? "pencil-simple" : "arrow-bend-up-left"; size: ui.px(14); color: root.c.accent }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - ui.px(23)
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: session.editing ? "Editing your message"
                  : "Replying to <font color=\"" + root.c.fg + "\">" + Format.escapeHtml(session.replyTo ? session.replyTo.sender_name : "") + "</font>"
                    + "  <font color=\"" + root.c.muted + "\">" + Format.escapeHtml(session.replyTo ? Format.oneLine(session.replyTo.body) : "") + "</font>"
                color: root.c.muted
                font.family: ui.sans; font.pixelSize: ui.f12
              }
            }
            IconButton { id: stripClose; anchors.right: parent.right; anchors.rightMargin: ui.px(6); anchors.verticalCenter: parent.verticalCenter; c: root.c; icon: "x"; size: ui.px(24); iconSize: ui.px(13); radius: ui.px(6); onClicked: session.cancelCompose() }
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
          }

          // Buttons and the text
          Item {
            width: parent.width
            height: Math.max(composer.implicitHeight + ui.px(12), ui.px(46))
            IconButton {
              id: attachButton
              anchors.left: parent.left
              anchors.leftMargin: ui.px(6)
              anchors.bottom: parent.bottom
              anchors.bottomMargin: ui.px(6)
              c: root.c; tips: root.tips
              icon: "paperclip"; subtle: false
              tooltip: "Attach a file"
              enabled: !session.busy && root.roomId !== ""
              onClicked: session.attach()
            }
            Composer {
              id: composer
              anchors.left: attachButton.right
              anchors.right: emojiButton.left
              anchors.leftMargin: ui.px(2)
              anchors.rightMargin: ui.px(2)
              anchors.bottom: parent.bottom
              anchors.bottomMargin: ui.px(6)
              framed: false
              paddingX: ui.px(4)
              paddingY: ui.px(8)
              fontFamily: ui.sans
              fontSize: ui.px(13.5)
              foreground: root.c.fg
              accent: root.c.accent
              placeholderColor: root.c.muted
              selectionFill: root.c.sel
              maximumLength: 4000
              placeholderText: session.uploads > 0 ? "Sending " + session.uploads + " file" + (session.uploads === 1 ? "" : "s") + "…"
                : session.editing ? "Edit your message" : session.replyTo ? "Write a reply"
                : session.inThread ? "Reply in the thread"
                : (root.encrypted ? "Encrypted message to " + root.roomName : "Message " + root.roomName)
              enabled: !session.busy && root.roomId !== ""
              onAccepted: session.accept()
              onTextChanged: { session.noteTyping(); session.updateEmojiHints() }
              onCursorPositionChanged: session.updateEmojiHints()
              onKeyPressed: function(event) { if (session.handleComposerKey(event)) event.accepted = true }
            }
            IconButton {
              id: emojiButton
              anchors.right: micButton.left
              anchors.bottom: parent.bottom
              anchors.bottomMargin: ui.px(6)
              c: root.c; tips: root.tips
              icon: "smiley"; subtle: false
              tooltip: "Emoji"
              enabled: !session.busy && root.roomId !== ""
              onClicked: { composer.forceActiveFocus(); root.service.openEmojiPicker() }
            }
            IconButton {
              id: micButton
              anchors.right: sendButton.left
              anchors.bottom: parent.bottom
              anchors.bottomMargin: ui.px(6)
              c: root.c; tips: root.tips
              icon: "microphone"; subtle: false
              tooltip: "Record a voice message (Ctrl+M)"
              enabled: !session.busy && root.roomId !== "" && root.service && !root.service.recording
              onClicked: session.startVoice()
            }
            Rectangle {
              id: sendButton
              anchors.right: parent.right
              anchors.rightMargin: ui.px(8)
              anchors.bottom: parent.bottom
              anchors.bottomMargin: ui.px(6)
              width: ui.px(34); height: ui.px(34); radius: ui.px(8)
              readonly property bool ready: root.hasDraft && !session.busy
              color: ready ? (sendMouse.containsMouse ? Qt.lighter(root.c.accent, 1.14) : root.c.accent) : root.c.chip
              Behavior on color { ColorAnimation { duration: 120 } }
              Icon { anchors.centerIn: parent; name: session.editing ? "check" : "paper-plane-right"; weight: "fill"; size: ui.px(15); color: parent.ready ? root.c.bg2 : root.c.muted }
              MouseArea {
                id: sendMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: session.send()
                onContainsMouseChanged: { if (!root.tips) return; if (containsMouse) root.tips.show(sendButton, session.editing ? "Save the edit" : "Send"); else root.tips.hide(sendButton) }
              }
            }
          }
        }
      }
    }

    // Hint row
    Item {
      width: parent.width
      height: ui.px(16)
      Row {
        id: keyHints
        anchors.left: parent.left
        anchors.leftMargin: ui.px(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(14)
        // A narrow column keeps the encryption note and drops the keys.
        visible: implicitWidth + encryptionNote.implicitWidth + ui.px(30) <= parent.width
        Row { spacing: ui.px(5); Kbd { label: "Enter"; anchors.verticalCenter: parent.verticalCenter } Text { anchors.verticalCenter: parent.verticalCenter; text: "send"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) } }
        Row { spacing: ui.px(5); Kbd { label: "Shift+Enter"; anchors.verticalCenter: parent.verticalCenter } Text { anchors.verticalCenter: parent.verticalCenter; text: "newline"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) } }
        Row { spacing: ui.px(5); Kbd { label: "↑"; anchors.verticalCenter: parent.verticalCenter } Text { anchors.verticalCenter: parent.verticalCenter; text: "edit last"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) } }
        Row { spacing: ui.px(5); Kbd { label: "Ctrl+M"; anchors.verticalCenter: parent.verticalCenter } Text { anchors.verticalCenter: parent.verticalCenter; text: "voice"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) } }
      }
      Row {
        id: encryptionNote
        anchors.right: parent.right
        anchors.rightMargin: ui.px(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(5)
        Icon { anchors.verticalCenter: parent.verticalCenter; name: root.encrypted ? "lock-simple" : "lock-simple-open"; weight: "fill"; size: ui.px(10); color: root.encrypted ? root.c.ok : root.c.warn }
        Text { anchors.verticalCenter: parent.verticalCenter; text: root.encrypted ? "End-to-end encrypted" : "Not encrypted"; color: root.encrypted ? root.c.ok : root.c.warn; font.family: ui.sans; font.pixelSize: ui.px(10.5) }
      }
    }
  }

  // Drop a file to send it
  DropArea {
    id: drop
    anchors.fill: parent
    enabled: root.roomId !== ""
    onDropped: function(d) { if (d.hasUrls) { session.sendFiles(d.urls); d.accept() } }
  }
  Rectangle {
    anchors.fill: parent
    visible: drop.containsDrag
    z: 10
    radius: ui.px(10)
    color: Qt.rgba(root.c.accent.r, root.c.accent.g, root.c.accent.b, 0.12)
    border.width: 2
    border.color: root.c.accent
    Column {
      anchors.centerIn: parent
      spacing: ui.px(8)
      Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "paperclip"; size: ui.px(28); color: root.c.accent }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Drop to send" + (root.encrypted ? " (encrypted)" : ""); color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f14; font.weight: Font.DemiBold }
    }
  }
}

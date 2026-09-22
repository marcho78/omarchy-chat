import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../../shared"
import "../../shared/Format.js" as Format

// One room: recent history, live messages, composer. Set `room` (an object
// from the service's room list or a command result) to show it; clear it
// with `close()`. `viewId` identifies this view to the service so incoming
// messages here don't raise notifications while it is visible.
//
// Everything that is not drawing lives in the shared RoomSession; this
// file is the Omarchy look for it.
Item {
  id: root
  property var service: null
  property string viewId: "room"
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property bool showLeave: true
  property real timelineHeight: Style.space(340)
  property bool fillHeight: false   // the window gives us a fixed height instead

  property alias room: session.room
  readonly property string roomId: session.roomId
  readonly property string roomName: session.roomName
  readonly property bool encrypted: session.encrypted
  readonly property bool busy: session.busy
  readonly property string errorText: session.errorText
  readonly property string threadRoot: session.threadRoot
  readonly property bool inThread: session.inThread

  signal roomLeft()
  // Someone wants the thread under a message opened (the host shows it).
  signal threadRequested(string eventId)
  // Esc in a thread with nothing to cancel: the host closes the thread.
  signal closeRequested()

  implicitHeight: column.implicitHeight
  readonly property bool hasTextFocus: composer.hasFocus
  function focusComposer() { composer.forceActiveFocus() }

  function open(r) { session.open(r) }
  function openAt(r, eventId) { session.openAt(r, eventId) }
  function openThread(r, rootId) { session.openThread(r, rootId) }
  function close() { session.close() }
  function jumpTo(eventId) { session.jumpTo(eventId) }

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
  function snapToEnd() {
    msgList.positionViewAtEnd()
    settle.restart()
  }
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
    radius: Style.space(8)
    color: Util.alpha(root.service ? root.service.accent : Color.accent, 0.12)
    border.width: 2
    border.color: root.service ? root.service.accent : Color.accent
    Text {
      anchors.centerIn: parent
      text: "󰁦  Drop to send" + (root.encrypted ? " (encrypted)" : "")
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
    }
  }

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: root.fillHeight ? parent.bottom : undefined
    spacing: Style.space(8)

    ListView {
      id: msgList
      width: parent.width
      // Fill mode: whatever the rows below leave over (a Column skips
      // invisible and zero-height children, so count only the rest).
      readonly property real below: {
        var rows = [typingItem, confirmBox, replyStrip, composerRow, errorLabel, leaveButton]
        var h = 0
        for (var i = 0; i < rows.length; i++) if (rows[i].visible && rows[i].height > 0) h += rows[i].height + column.spacing
        return h
      }
      // Where the list stood before older rows were inserted above it.
      property real keptHeight: 0
      property real keptY: 0
      height: root.fillHeight ? column.height - below : root.timelineHeight
      clip: true
      spacing: 0
      model: session.model
      cacheBuffer: 2000
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      // Reaching the top loads the page before it.
      onContentYChanged: if (contentY <= originY + Style.space(40) && session.hasOlder && !session.loadingOlder && count > 0) session.loadOlder()
      // A manual scroll up releases the bottom anchor.
      onDraggingChanged: if (dragging) session.stickToEnd = false
      onFlickingChanged: if (flicking && !atYEnd) session.stickToEnd = false
      onAtYEndChanged: if (atYEnd) session.stickToEnd = true
      // The composer growing shrinks the list; keep the end in view.
      onHeightChanged: if (session.stickToEnd) Qt.callLater(root.snapToEnd)

      header: Item {
        width: msgList.width
        height: session.hasOlder || session.loadingOlder ? Style.space(40) : (session.count > 0 ? Style.space(28) : 0)
        Button {
          anchors.centerIn: parent
          visible: session.hasOlder || session.loadingOlder
          text: session.loadingOlder ? "Loading…" : "Load earlier messages"
          enabled: !session.loadingOlder
          onClicked: session.loadOlder()
        }
        Text {
          anchors.centerIn: parent
          visible: !session.hasOlder && !session.loadingOlder && session.count > 0
          text: "Beginning of the conversation"
          color: root.fg; opacity: 0.4
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
      delegate: MessageRow {
        required property var model
        required property int index
        width: msgList.width
        sender: model.sender
        senderName: model.senderName
        senderAvatar: model.senderAvatar
        body: model.body
        html: model.html
        msgtype: model.msgtype
        attachment: model.attachmentJson !== "" ? JSON.parse(model.attachmentJson) : null
        roomId: root.roomId
        eventId: model.eventId
        service: root.service
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
        onReactRequested: function(key) { session.toggleReaction(model.eventId, key) }
        onDeleteRequested: session.confirmDelete = { event_id: model.eventId, body: model.body }
        highlighted: index === session.flashIndex
        canEdit: model.mine && !model.attachmentJson && !model.deleted
        canDelete: model.mine && !model.deleted
        onReplyRequested: session.startReply({ event_id: model.eventId, sender_name: model.senderName, body: model.body })
        onEditRequested: session.startEdit({ event_id: model.eventId, body: model.body })
        onJumpRequested: function(id) { session.jumpTo(id) }
        threadInfo: model.threadJson !== "" ? JSON.parse(model.threadJson) : null
        inThread: root.inThread
        isThreadRoot: root.inThread && model.eventId === root.threadRoot
        onThreadRequested: root.threadRequested(model.eventId)
        fg: root.fg
        accent: root.service ? root.service.accent : Color.accent
        bg: root.service ? root.service.bg : Color.popups.background
        hover: root.service ? root.service.hover : Util.alpha(Color.foreground, 0.05)
        bubbles: root.service ? root.service.bubbles : false
        showAvatars: root.service ? root.service.showAvatars : true
        senderColors: root.service ? root.service.senderColors : true
        scale: root.service ? root.service.fontScale : 1.0
        fontFamily: root.fontFamily
      }
    }

    // Who is typing
    Item {
      id: typingItem
      width: parent.width
      height: session.typingText !== "" ? Style.space(18) : 0
      visible: height > 0
      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(4)
        spacing: Style.space(6)
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Repeater {
            model: 3
            delegate: Rectangle {
              required property int index
              width: 5; height: 5; radius: 2.5
              color: root.fg
              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: session.typingText !== ""
                PauseAnimation { duration: index * 160 }
                NumberAnimation { to: 1; duration: 320 }
                NumberAnimation { to: 0.25; duration: 320 }
                PauseAnimation { duration: (2 - index) * 160 }
              }
            }
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: session.typingText
          color: root.fg; opacity: 0.6
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
    }

    // Delete confirmation
    Rectangle {
      id: confirmBox
      width: parent.width
      visible: session.confirmDelete !== null
      implicitHeight: visible ? delRow.implicitHeight + Style.space(12) : 0
      radius: Style.space(8)
      color: Util.alpha(Color.urgent, 0.12)
      border.width: 1
      border.color: Color.urgent
      Row {
        id: delRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(10)
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(10) - delButtons.width
          spacing: Style.space(1)
          Text { text: "Delete this message?"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          Text {
            width: parent.width
            text: session.confirmDelete ? (session.confirmDelete.body || "(attachment)") : ""
            color: root.fg; opacity: 0.7; elide: Text.ElideRight
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Row {
          id: delButtons
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.controlGap
          Button { text: "Delete"; bordered: true; onClicked: session.deleteMessage(session.confirmDelete.event_id) }
          Button { text: "Keep"; onClicked: session.confirmDelete = null }
        }
      }
    }

    // Replying to / editing strip
    Rectangle {
      id: replyStrip
      width: parent.width
      visible: session.replyTo !== null || session.editing !== null
      implicitHeight: visible ? stripRow.implicitHeight + Style.space(12) : 0
      radius: Style.space(8)
      color: Util.alpha(root.service ? root.service.accent : Color.accent, 0.1)
      Row {
        id: stripRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(6)
        spacing: Style.space(10)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: session.editing ? "󰏫" : "󰑚"
          color: root.service ? root.service.accent : Color.accent
          font.family: root.fontFamily; font.pixelSize: Style.font.icon
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(10) * 2 - Style.space(24) - stripClose.width
          spacing: Style.space(1)
          Text {
            text: session.editing ? "Editing message" : ("Replying to " + (session.replyTo ? session.replyTo.sender_name : ""))
            color: root.service ? root.service.accent : Color.accent
            font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          }
          Text {
            width: parent.width
            text: session.editing ? session.editing.body : (session.replyTo ? session.replyTo.body : "")
            color: root.fg; opacity: 0.7
            elide: Text.ElideRight
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Button { id: stripClose; anchors.verticalCenter: parent.verticalCenter; iconText: "󰅖"; text: ""; onClicked: session.cancelCompose() }
      }
    }

    Row {
      id: composerRow
      width: parent.width
      spacing: Style.spacing.controlGap
      Button {
        id: attachButton
        anchors.bottom: parent.bottom
        iconText: "󰁦"
        text: ""
        enabled: !session.busy && root.roomId !== ""
        onClicked: session.attach()
      }
      Button {
        id: emojiButton
        anchors.bottom: parent.bottom
        iconText: "󰞅"
        text: ""
        visible: !session.recordingHere
        enabled: !session.busy && root.roomId !== ""
        onClicked: { composer.forceActiveFocus(); root.service.openEmojiPicker() }
      }
      Button {
        id: micButton
        anchors.bottom: parent.bottom
        iconText: "󰍬"
        text: ""
        visible: !session.recordingHere
        enabled: !session.busy && root.roomId !== "" && root.service && !root.service.recording
        onClicked: session.startVoice()
      }
      // Recording: a pulsing dot and the clock take the composer's place.
      Rectangle {
        id: recordStrip
        visible: session.recordingHere
        anchors.bottom: parent.bottom
        width: parent.width - sendButton.width - attachButton.width - cancelRecord.width - 3 * Style.spacing.controlGap
        height: composer.implicitHeight
        radius: Style.cornerRadius
        color: Util.alpha(Color.urgent, 0.10)
        border.width: 1
        border.color: Util.alpha(Color.urgent, 0.5)
        // The composer is hidden meanwhile, so the strip takes the keys.
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { event.accepted = true; session.stopVoice(true) }
          else if (event.key === Qt.Key_Escape) { event.accepted = true; session.stopVoice(false) }
        }
        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)
          Rectangle {
            id: recordDot
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(10); height: width; radius: width / 2
            color: Color.urgent
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: session.recordingHere
              NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - recordDot.width - parent.spacing
            elide: Text.ElideRight
            text: "Recording  " + Format.clock(root.service ? root.service.recordSeconds : 0)
              + "   <font color=\"" + Util.alpha(root.fg, 0.55) + "\">Enter sends · Esc discards</font>"
            textFormat: Text.StyledText
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
        }
      }
      Button {
        id: cancelRecord
        anchors.bottom: parent.bottom
        visible: session.recordingHere
        iconText: "󰅖"
        text: ""
        onClicked: session.stopVoice(false)
      }
      Composer {
        id: composer
        visible: !session.recordingHere
        width: parent.width - sendButton.width - attachButton.width - emojiButton.width - micButton.width - 4 * Style.spacing.controlGap
        maximumLength: 4000
        foreground: root.fg
        accent: root.service ? root.service.accent : Color.accent
        placeholderText: session.uploads > 0 ? "Sending " + session.uploads + " file" + (session.uploads === 1 ? "" : "s") + "…"
          : session.editing ? "Edit your message…" : session.replyTo ? "Write a reply…"
          : session.inThread ? "Reply in thread…"
          : (root.encrypted ? "Encrypted message…" : "Message (not encrypted)…")
        enabled: !session.busy && root.roomId !== ""
        onAccepted: session.accept()
        onTextChanged: { session.noteTyping(); session.updateEmojiHints() }
        onCursorPositionChanged: session.updateEmojiHints()
        onKeyPressed: function(event) { if (session.handleComposerKey(event)) event.accepted = true }
      }
      Button {
        id: sendButton
        anchors.bottom: parent.bottom
        text: session.busy ? "…" : (session.editing ? "Save" : "Send")
        iconText: session.editing ? "󰄬" : "󰒊"
        enabled: !session.busy && root.roomId !== ""
        onClicked: session.recordingHere ? session.stopVoice(true) : session.send()
      }
    }

    Text {
      id: errorLabel
      width: parent.width
      wrapMode: Text.WordWrap
      visible: session.errorText !== ""
      height: visible ? implicitHeight : 0
      text: session.errorText
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Row {
      id: leaveButton
      visible: root.showLeave && !root.inThread && root.roomId !== ""
      spacing: Style.spacing.controlGap
      property bool confirm: false
      Button {
        visible: !leaveButton.confirm
        text: "Leave room"
        enabled: !session.busy
        onClicked: leaveButton.confirm = true
      }
      Text {
        visible: leaveButton.confirm
        anchors.verticalCenter: parent.verticalCenter
        text: "Leave " + root.roomName + "?"
        color: root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
      Button { visible: leaveButton.confirm; text: session.busy ? "…" : "Leave"; bordered: true; enabled: !session.busy; onClicked: { leaveButton.confirm = false; session.leave() } }
      Button { visible: leaveButton.confirm; text: "Stay"; onClicked: leaveButton.confirm = false }
    }
  }

  // Overlays over the bottom of the message list. They live outside the
  // Column because a positioner does not place zero-height children.
  Rectangle {
    id: emojiPop
    visible: session.emojiHits.length > 0
    x: column.x + msgList.x
    y: column.y + msgList.y + msgList.height - height - Style.space(8)
    width: Math.min(msgList.width, hintRow.implicitWidth + Style.space(12))
    height: Style.space(48)
    radius: Style.space(10)
    color: root.service ? root.service.bg : Color.background
    border.width: 1
    border.color: Util.alpha(root.fg, 0.25)
    Row {
      id: hintRow
      anchors.centerIn: parent
      spacing: Style.space(2)
      Repeater {
        model: session.emojiHits
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: Math.max(hintLabel.implicitWidth, Style.space(40)) + Style.space(10)
          height: Style.space(40)
          radius: Style.space(7)
          color: index === session.emojiIndex ? Util.alpha(root.service ? root.service.accent : Color.accent, 0.22)
               : (hintMouse.containsMouse ? (root.service ? root.service.hover : Util.alpha(root.fg, 0.06)) : "transparent")
          border.width: index === session.emojiIndex ? 1 : 0
          border.color: root.service ? root.service.accent : Color.accent
          Column {
            id: hintCol
            anchors.centerIn: parent
            spacing: 0
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.e; font.pixelSize: Style.space(17) }
            Text {
              id: hintLabel
              anchors.horizontalCenter: parent.horizontalCenter
              text: ":" + (modelData.k.length > 14 ? modelData.k.substring(0, 13) + "…" : modelData.k)
              color: root.fg; opacity: 0.6
              font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2
            }
          }
          MouseArea { id: hintMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: session.insertEmoji(index) }
        }
      }
    }
  }

  // "N new messages" pill when new messages arrived below the fold
  Rectangle {
    visible: session.pendingNew > 0 && !session.atEnd
    x: column.x + msgList.x + (msgList.width - width) / 2
    y: column.y + msgList.y + msgList.height - height - Style.space(10)
    width: pillText.implicitWidth + Style.space(28)
    height: Style.space(32)
    radius: height / 2
    color: root.service ? root.service.accent : Color.accent
    Text {
      id: pillText
      anchors.centerIn: parent
      text: "󰁅  " + session.pendingNew + " new message" + (session.pendingNew === 1 ? "" : "s")
      color: root.service ? root.service.bg : Color.background
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: session.jumpToNew() }
  }
}

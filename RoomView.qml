import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Format.js" as Format

// One room: recent history, live messages, composer. Set `room` (an object
// from the service's room list or a command result) to show it; clear it
// with `close()`. `viewId` identifies this view to the service so incoming
// messages here don't raise notifications while it is visible.
Item {
  id: root
  property var service: null
  property string viewId: "room"
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property bool showLeave: true
  property real timelineHeight: Style.space(340)
  property bool fillHeight: false   // the window gives us a fixed height instead

  property var room: null
  readonly property string roomId: room ? String(room.id) : ""
  readonly property string roomName: room ? String(room.name) : ""
  readonly property bool encrypted: room ? room.encrypted === true : false
  property bool busy: false
  property string errorText: ""

  signal roomLeft()

  implicitHeight: column.implicitHeight
  readonly property bool hasTextFocus: composer.activeFocus
  function focusComposer() { composer.forceActiveFocus() }

  ListModel { id: msgModel }

  // Paging: `nextToken` points at the page before the oldest loaded one;
  // empty once history is exhausted.
  property string nextToken: ""
  property bool loadingOlder: false
  readonly property bool hasOlder: nextToken !== ""

  // ---------- read state ----------
  // A message counts as read only when this view is visible and the list
  // is at its end. Otherwise it stays unread and the pill offers to jump.
  property int pendingNew: 0
  property string lastEventId: ""
  readonly property bool atEnd: msgList.atYEnd || msgList.contentHeight <= msgList.height
  function maybeMarkRead() {
    if (!root.roomId || !root.visible || !root.atEnd || root.lastEventId === "") return
    if (root.pendingNew === 0 && root.readUpTo === root.lastEventId) return
    root.pendingNew = 0
    root.readUpTo = root.lastEventId
    root.service.markRead(root.roomId, root.lastEventId)
  }
  property string readUpTo: ""
  onAtEndChanged: if (atEnd) maybeMarkRead()
  onVisibleChanged: { if (root.service) root.service.setViewing(root.viewId, visible ? root.roomId : ""); if (visible) Qt.callLater(maybeMarkRead) }
  function jumpToNew() { msgList.positionViewAtEnd(); Qt.callLater(function() { msgList.positionViewAtEnd(); root.maybeMarkRead() }) }

  function open(r) {
    root.room = r
    root.errorText = ""
    root.nextToken = ""
    root.loadingOlder = false
    root.pendingNew = 0
    root.lastEventId = ""
    root.readUpTo = ""
    msgModel.clear()
    root.service.setViewing(root.viewId, root.roomId)
    var id = root.roomId
    var marker = r.read_marker || ""
    root.service.timeline(id, 60, "", function(res) {
      if (root.roomId !== id) return
      if (!res.ok) { root.errorText = res.error || "Could not load messages"; return }
      var list = res.result.messages
      root.nextToken = res.result.next || ""
      if (list.length === 0) return
      var dividerAt = -1
      for (var i = 0; i < list.length; i++) {
        root.append(list[i])
        // First message after our marker, from someone else, starts the unread run.
        if (dividerAt === -1 && marker !== "" && i > 0 && list[i - 1].event_id === marker && list[i].sender !== root.service.userId) dividerAt = i
      }
      root.lastEventId = list[list.length - 1].event_id
      root.readUpTo = marker
      if (dividerAt > 0) {
        msgModel.setProperty(dividerAt, "newDivider", true)
        msgModel.setProperty(dividerAt, "header", true)
        Qt.callLater(function() { msgList.positionViewAtIndex(dividerAt, ListView.Beginning); Qt.callLater(root.maybeMarkRead) })
      } else {
        Qt.callLater(function() { msgList.positionViewAtEnd(); Qt.callLater(root.maybeMarkRead) })
      }
      Qt.callLater(function() { composer.forceActiveFocus() })
    })
  }

  function loadOlder() {
    if (!root.hasOlder || root.loadingOlder || !root.roomId) return
    root.loadingOlder = true
    var id = root.roomId
    var token = root.nextToken
    root.service.timeline(id, 60, token, function(res) {
      root.loadingOlder = false
      if (root.roomId !== id) return
      if (!res.ok) { root.errorText = res.error || "Could not load earlier messages"; return }
      root.nextToken = res.result.next || ""
      root.prepend(res.result.messages)
    })
  }

  function close() {
    root.room = null
    root.replyTo = null
    root.editing = null
    msgModel.clear()
    root.service.setViewing(root.viewId, "")
  }

  // Group a message under the previous header when it is the same sender
  // within five minutes on the same day; start a day divider on a new day.
  readonly property int groupWindowMs: 5 * 60 * 1000
  function metaFor(prev, m) {
    var ts = Number(m.ts) || 0
    var newDay = !prev || !Format.isSameDay(prev.ts, ts)
    return {
      header: newDay || !prev || prev.sender !== m.sender || (ts - prev.ts) > groupWindowMs,
      dayLabel: newDay ? Format.dayLabel(ts, Date.now()) : ""
    }
  }
  function entryFor(m, meta) {
    return {
      eventId: m.event_id,
      sender: m.sender,
      senderName: m.sender_name || m.sender,
      body: m.body,
      html: m.html || "",
      msgtype: m.msgtype || "m.text",
      attachmentJson: m.attachment ? JSON.stringify(m.attachment) : "",
      replyJson: m.reply_to ? JSON.stringify(m.reply_to) : "",
      edited: m.edited === true,
      ts: Number(m.ts) || 0,
      mine: m.sender === root.service.userId,
      encrypted: m.encrypted === true,
      header: meta.header,
      dayLabel: meta.dayLabel,
      newDivider: false
    }
  }

  // Older messages go in at the top; the view keeps its place by growing
  // contentY by exactly what was added above it.
  function prepend(list) {
    if (list.length === 0) return
    var oldHeight = msgList.contentHeight
    var oldY = msgList.contentY
    var prev = null
    for (var i = 0; i < list.length; i++) {
      var meta = root.metaFor(prev, list[i])
      msgModel.insert(i, root.entryFor(list[i], meta))
      prev = { ts: Number(list[i].ts) || 0, sender: list[i].sender }
    }
    // The item that used to be first is now preceded by real history.
    if (msgModel.count > list.length) {
      var first = msgModel.get(list.length)
      var m2 = root.metaFor(prev, { ts: first.ts, sender: first.sender })
      msgModel.setProperty(list.length, "header", m2.header)
      msgModel.setProperty(list.length, "dayLabel", m2.dayLabel)
    }
    Qt.callLater(function() { msgList.contentY = oldY + (msgList.contentHeight - oldHeight) })
  }

  function append(m) {
    var ts = Number(m.ts) || 0
    var prev = msgModel.count > 0 ? msgModel.get(msgModel.count - 1) : null
    var newDay = !prev || !Format.isSameDay(prev.ts, ts)
    var header = newDay || !prev || prev.sender !== m.sender || (ts - prev.ts) > groupWindowMs
    msgModel.append({
      eventId: m.event_id,
      sender: m.sender,
      senderName: m.sender_name || m.sender,
      body: m.body,
      html: m.html || "",
      msgtype: m.msgtype || "m.text",
      attachmentJson: m.attachment ? JSON.stringify(m.attachment) : "",
      replyJson: m.reply_to ? JSON.stringify(m.reply_to) : "",
      edited: m.edited === true,
      ts: ts,
      mine: m.sender === root.service.userId,
      encrypted: m.encrypted === true,
      header: header,
      dayLabel: newDay ? Format.dayLabel(ts, Date.now()) : "",
      newDivider: false
    })
  }

  Connections {
    target: root.service
    function onMessageEdited(e) {
      if (!root.roomId || e.room !== root.roomId) return
      var i = root.indexOfEvent(e.event_id)
      if (i < 0) return
      msgModel.setProperty(i, "body", e.body)
      msgModel.setProperty(i, "html", e.html || "")
      msgModel.setProperty(i, "edited", true)
    }
    function onMessageReceived(m) {
      if (!root.roomId || m.room !== root.roomId) return
      var wasAtEnd = root.atEnd
      root.append(m)
      root.lastEventId = m.event_id
      if (m.sender === root.service.userId || (wasAtEnd && root.visible)) {
        Qt.callLater(function() { msgList.positionViewAtEnd(); root.maybeMarkRead() })
      } else {
        root.pendingNew++
      }
    }
  }

  // ---------- reply / edit ----------
  // One of these at a time; the strip above the composer shows which.
  property var replyTo: null      // {event_id, sender_name, body}
  property var editing: null      // {event_id, body}
  function startReply(m) { root.editing = null; root.replyTo = m; composer.forceActiveFocus() }
  function startEdit(m) { root.replyTo = null; root.editing = m; composer.text = m.body; composer.forceActiveFocus(); composer.cursorPosition = composer.text.length }
  function cancelCompose() { if (root.editing) composer.text = ""; root.replyTo = null; root.editing = null }
  function indexOfEvent(eventId) {
    for (var i = 0; i < msgModel.count; i++) if (msgModel.get(i).eventId === eventId) return i
    return -1
  }
  function jumpTo(eventId) {
    var i = root.indexOfEvent(eventId)
    if (i >= 0) { msgList.positionViewAtIndex(i, ListView.Center); root.flashIndex = i; flashTimer.restart() }
  }
  property int flashIndex: -1
  Timer { id: flashTimer; interval: 1200; onTriggered: root.flashIndex = -1 }

  function send() {
    var text = composer.text
    if (text.trim() === "" || !root.roomId || root.busy) return
    root.busy = true
    if (root.editing) {
      var target = root.editing.event_id
      root.service.edit(root.roomId, target, text, function(r) {
        root.busy = false
        if (!r.ok) { root.errorText = r.error || "Edit failed"; return }
        composer.text = ""; root.errorText = ""; root.editing = null
        var i = root.indexOfEvent(target)
        if (i >= 0) { msgModel.setProperty(i, "body", text); msgModel.setProperty(i, "html", ""); msgModel.setProperty(i, "edited", true) }
      })
      return
    }
    var reply = root.replyTo ? root.replyTo.event_id : ""
    root.service.send(root.roomId, text, reply, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Send failed"
      else { composer.text = ""; root.errorText = ""; root.replyTo = null; Qt.callLater(function() { msgList.positionViewAtEnd() }) }
    })
  }

  // ---------- attachments ----------

  property int uploads: 0
  function sendFiles(paths) {
    for (var i = 0; i < paths.length; i++) {
      var p = String(paths[i]).replace(/^file:\/\//, "")
      if (p === "") continue
      root.uploads++
      root.service.sendFile(root.roomId, p, "", function(r) {
        root.uploads--
        if (!r.ok) root.errorText = r.error || "Could not send the file"
      })
    }
  }

  FileDialog {
    id: fileDialog
    title: "Send a file"
    fileMode: FileDialog.OpenFiles
    onAccepted: root.sendFiles(selectedFiles)
  }

  // Ctrl+V with an image on the clipboard sends it; otherwise it pastes text.
  Process {
    id: pasteProc
    property string out: ""
    command: ["/usr/bin/bash", "-c",
      "if wl-paste -l 2>/dev/null | grep -q '^image/'; then f=\"${XDG_RUNTIME_DIR:-/tmp}/yapper-paste-$(date +%s%N).png\"; wl-paste -t image/png > \"$f\" && echo \"$f\"; fi"]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { pasteProc.out += d } }
    onStarted: out = ""
    onExited: function() {
      var p = pasteProc.out.trim()
      if (p !== "") root.sendFiles([p])
      else composer.paste()
    }
  }

  function leave() {
    if (!root.roomId || root.busy) return
    root.busy = true
    root.service.leave(root.roomId, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not leave"; return }
      root.close()
      root.roomLeft()
    })
  }

  DropArea {
    id: drop
    anchors.fill: parent
    enabled: root.roomId !== ""
    onDropped: function(d) { if (d.hasUrls) { root.sendFiles(d.urls); d.accept() } }
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
      height: root.fillHeight ? column.height - composerRow.height - (leaveButton.visible ? leaveButton.height : 0) - errorLabel.height - column.spacing * 3 : root.timelineHeight
      clip: true
      spacing: 0
      model: msgModel
      cacheBuffer: 2000
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      // Reaching the top loads the page before it.
      onContentYChanged: if (contentY <= originY + Style.space(40) && root.hasOlder && !root.loadingOlder && count > 0) root.loadOlder()

      header: Item {
        width: msgList.width
        height: root.hasOlder || root.loadingOlder ? Style.space(40) : (msgModel.count > 0 ? Style.space(28) : 0)
        Button {
          anchors.centerIn: parent
          visible: root.hasOlder || root.loadingOlder
          text: root.loadingOlder ? "Loading…" : "Load earlier messages"
          enabled: !root.loadingOlder
          onClicked: root.loadOlder()
        }
        Text {
          anchors.centerIn: parent
          visible: !root.hasOlder && !root.loadingOlder && msgModel.count > 0
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
        highlighted: index === root.flashIndex
        canEdit: model.mine && !model.attachmentJson
        onReplyRequested: root.startReply({ event_id: model.eventId, sender_name: model.senderName, body: model.body })
        onEditRequested: root.startEdit({ event_id: model.eventId, body: model.body })
        onJumpRequested: function(id) { root.jumpTo(id) }
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

    // "N new messages" pill when new messages arrived below the fold
    Item {
      width: parent.width
      height: 0
      Rectangle {
        visible: root.pendingNew > 0 && !root.atEnd
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(10)
        width: pillText.implicitWidth + Style.space(28)
        height: Style.space(32)
        radius: height / 2
        color: root.service ? root.service.accent : Color.accent
        Text {
          id: pillText
          anchors.centerIn: parent
          text: "󰁅  " + root.pendingNew + " new message" + (root.pendingNew === 1 ? "" : "s")
          color: root.service ? root.service.bg : Color.background
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.jumpToNew() }
      }
    }

    // Replying to / editing strip
    Rectangle {
      width: parent.width
      visible: root.replyTo !== null || root.editing !== null
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
          text: root.editing ? "󰏫" : "󰑚"
          color: root.service ? root.service.accent : Color.accent
          font.family: root.fontFamily; font.pixelSize: Style.font.icon
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(10) * 2 - Style.space(24) - stripClose.width
          spacing: Style.space(1)
          Text {
            text: root.editing ? "Editing message" : ("Replying to " + (root.replyTo ? root.replyTo.sender_name : ""))
            color: root.service ? root.service.accent : Color.accent
            font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          }
          Text {
            width: parent.width
            text: root.editing ? root.editing.body : (root.replyTo ? root.replyTo.body : "")
            color: root.fg; opacity: 0.7
            elide: Text.ElideRight
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Button { id: stripClose; anchors.verticalCenter: parent.verticalCenter; iconText: "󰅖"; text: ""; onClicked: root.cancelCompose() }
      }
    }

    Row {
      id: composerRow
      width: parent.width
      spacing: Style.spacing.controlGap
      Button {
        id: attachButton
        iconText: "󰁦"
        text: ""
        enabled: !root.busy && root.roomId !== ""
        onClicked: fileDialog.open()
      }
      TextField {
        id: composer
        width: parent.width - sendButton.width - attachButton.width - 2 * Style.spacing.controlGap
        maximumLength: 4000
        placeholderText: root.uploads > 0 ? "Sending " + root.uploads + " file" + (root.uploads === 1 ? "" : "s") + "…"
          : root.editing ? "Edit your message…" : root.replyTo ? "Write a reply…"
          : (root.encrypted ? "Encrypted message…" : "Message (not encrypted)…")
        enabled: !root.busy && root.roomId !== ""
        onAccepted: root.send()
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true
            if (!pasteProc.running) pasteProc.running = true
          } else if (event.key === Qt.Key_Escape && (root.replyTo || root.editing)) {
            event.accepted = true
            root.cancelCompose()
          } else if (event.key === Qt.Key_Up && composer.text === "" && !root.editing) {
            // Up in an empty composer edits your last message, like Slack/Element.
            for (var i = msgModel.count - 1; i >= 0; i--) {
              var it = msgModel.get(i)
              if (it.mine && it.attachmentJson === "") { event.accepted = true; root.startEdit({ event_id: it.eventId, body: it.body }); break }
            }
          }
        }
      }
      Button {
        id: sendButton
        text: root.busy ? "…" : (root.editing ? "Save" : "Send")
        iconText: root.editing ? "󰄬" : "󰒊"
        enabled: !root.busy && root.roomId !== ""
        onClicked: root.send()
      }
    }

    Text {
      id: errorLabel
      width: parent.width
      wrapMode: Text.WordWrap
      visible: root.errorText !== ""
      height: visible ? implicitHeight : 0
      text: root.errorText
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Button {
      id: leaveButton
      visible: root.showLeave && root.roomId !== ""
      text: "Leave room"
      enabled: !root.busy
      onClicked: root.leave()
    }
  }
}

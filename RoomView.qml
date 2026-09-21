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

  function open(r) {
    root.room = r
    root.errorText = ""
    root.nextToken = ""
    root.loadingOlder = false
    msgModel.clear()
    root.service.setViewing(root.viewId, root.roomId)
    var id = root.roomId
    root.service.timeline(id, 60, "", function(res) {
      if (root.roomId !== id) return
      if (!res.ok) { root.errorText = res.error || "Could not load messages"; return }
      var list = res.result.messages
      root.nextToken = res.result.next || ""
      if (list.length === 0) return
      for (var i = 0; i < list.length; i++) root.append(list[i])
      root.service.markRead(root.roomId, list[list.length - 1].event_id)
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
    msgModel.clear()
    root.service.setViewing(root.viewId, "")
  }

  // Visibility toggles whether we count as "viewing" for notifications.
  onVisibleChanged: if (root.service) root.service.setViewing(root.viewId, visible ? root.roomId : "")

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
      ts: Number(m.ts) || 0,
      mine: m.sender === root.service.userId,
      encrypted: m.encrypted === true,
      header: meta.header,
      dayLabel: meta.dayLabel
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
      ts: ts,
      mine: m.sender === root.service.userId,
      encrypted: m.encrypted === true,
      header: header,
      dayLabel: newDay ? Format.dayLabel(ts, Date.now()) : ""
    })
    Qt.callLater(function() { msgList.positionViewAtEnd() })
  }

  Connections {
    target: root.service
    function onMessageReceived(m) {
      if (!root.roomId || m.room !== root.roomId) return
      root.append(m)
      if (root.visible) root.service.markRead(root.roomId, m.event_id)
    }
  }

  function send() {
    var text = composer.text
    if (text.trim() === "" || !root.roomId || root.busy) return
    root.busy = true
    root.service.send(root.roomId, text, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Send failed"
      else { composer.text = ""; root.errorText = "" }
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
          : (root.encrypted ? "Encrypted message…" : "Message (not encrypted)…")
        enabled: !root.busy && root.roomId !== ""
        onAccepted: root.send()
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true
            if (!pasteProc.running) pasteProc.running = true
          }
        }
      }
      Button {
        id: sendButton
        text: root.busy ? "…" : "Send"
        iconText: "󰒊"
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

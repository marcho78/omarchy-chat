import QtQuick
import QtQuick.Controls
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

  function open(r) {
    root.room = r
    root.errorText = ""
    msgModel.clear()
    root.service.setViewing(root.viewId, root.roomId)
    root.service.timeline(root.roomId, 60, function(res) {
      if (!res.ok) { root.errorText = res.error || "Could not load messages"; return }
      if (res.result.length === 0) return
      for (var i = 0; i < res.result.length; i++) root.append(res.result[i])
      root.service.markRead(root.roomId, res.result[res.result.length - 1].event_id)
      Qt.callLater(function() { composer.forceActiveFocus() })
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
      delegate: MessageRow {
        required property var model
        width: msgList.width
        sender: model.sender
        senderName: model.senderName
        body: model.body
        html: model.html
        ts: model.ts
        mine: model.mine
        encrypted: model.encrypted
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
      TextField {
        id: composer
        width: parent.width - sendButton.width - Style.spacing.controlGap
        maximumLength: 4000
        placeholderText: root.encrypted ? "Encrypted message…" : "Message (not encrypted)…"
        enabled: !root.busy && root.roomId !== ""
        onAccepted: root.send()
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

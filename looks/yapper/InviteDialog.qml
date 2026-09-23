import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// Invite people to a room: search the homeserver's user directory, pick
// one or more, send.
Modal {
  id: root
  property var service: null
  property string roomId: ""
  property string roomName: ""
  icon: "user-plus"
  title: "Invite people"
  description: "Search the homeserver's user directory, or type a full Matrix ID."
  dialogWidth: ui.px(440)
  Ui { id: ui }

  property var hits: []
  property var picked: []
  property bool searching: false
  property bool busy: false
  property string errorText: ""
  property string doneText: ""
  readonly property bool hasTextFocus: field.hasFocus
  onOpenChanged: if (open) { field.text = ""; hits = []; picked = []; errorText = ""; doneText = ""; Qt.callLater(function() { field.forceActiveFocus() }) }
  Timer { id: debounce; interval: 350; onTriggered: root.search() }

  function search() {
    var q = field.text.trim()
    if (q === "") { root.hits = []; return }
    root.searching = true
    root.service.searchUsers(q.replace(/^@/, ""), function(r) {
      root.searching = false
      if (field.text.trim() !== q) return
      if (!r.ok) { root.errorText = r.error || "Search failed"; return }
      var list = r.result
      // A typed full id is always offered.
      if (/^@[^:\s]+:[^\s]+$/.test(q) && !list.some(function(u) { return u.id === q })) list = [{ id: q, name: q }].concat(list)
      root.hits = list
    })
  }
  function isPicked(id) { return root.picked.some(function(u) { return u.id === id }) }
  function toggle(user) {
    if (isPicked(user.id)) root.picked = root.picked.filter(function(u) { return u.id !== user.id })
    else root.picked = root.picked.concat([user])
  }
  function send() {
    if (root.busy || root.picked.length === 0) return
    root.busy = true; root.errorText = ""
    var left = root.picked.length, failed = []
    root.picked.forEach(function(u) {
      root.service.invite(root.roomId, u.id, function(r) {
        if (!r.ok) failed.push(u.id + ": " + (r.error || "failed"))
        if (--left === 0) {
          root.busy = false
          if (failed.length) { root.errorText = failed.join("\n"); return }
          root.doneText = root.picked.length === 1 ? "Invited " + root.picked[0].id : "Invited " + root.picked.length + " people"
          root.picked = []
          field.text = ""; root.hits = []
        }
      })
    })
  }

  Field {
    id: field
    c: root.c
    width: parent.width
    height: ui.px(40)
    icon: "at"
    placeholder: "name or @user:server"
    maximumLength: 256
    border.color: root.c.accent
    onTextChanged: { root.errorText = ""; root.doneText = ""; debounce.restart() }
    onAccepted: { debounce.stop(); root.search() }
    onEscaped: root.close()
  }
  Column {
    width: parent.width
    spacing: ui.px(2)
    Repeater {
      model: root.hits
      delegate: Rectangle {
        required property var modelData
        readonly property bool on: root.isPicked(modelData.id)
        width: parent.width
        height: ui.px(48)
        radius: ui.px(8)
        color: on ? root.c.sel : (hitMouse.containsMouse ? root.c.hover : "transparent")
        Avatar { id: hitAvatar; anchors.left: parent.left; anchors.leftMargin: ui.px(10); anchors.verticalCenter: parent.verticalCenter; service: root.service; userId: modelData.id; name: modelData.name || modelData.id; size: ui.px(30); fallbackColor: Palettes.colorOf(modelData.id, root.c.light); initialColor: root.c.bg2; fontFamily: ui.sans }
        Column {
          anchors.left: hitAvatar.right
          anchors.leftMargin: ui.px(11)
          anchors.right: check.left
          anchors.rightMargin: ui.px(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: ui.px(1)
          Text { textFormat: Text.PlainText; width: parent.width; text: modelData.name || modelData.id; color: root.c.fg; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.Medium }
          Text { textFormat: Text.PlainText; width: parent.width; text: modelData.id; color: root.c.muted; elide: Text.ElideMiddle; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
        }
        Icon { id: check; anchors.right: parent.right; anchors.rightMargin: ui.px(12); anchors.verticalCenter: parent.verticalCenter; visible: parent.on; name: "check-circle"; weight: "fill"; size: ui.px(17); color: root.c.accent }
        MouseArea { id: hitMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle(parent.modelData) }
      }
    }
    Text { width: parent.width; visible: root.searching; text: "Searching…"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
    Text { width: parent.width; visible: !root.searching && root.hits.length === 0 && field.text.trim() !== ""; text: "No one found. A full @user:server works even when the directory does not know them."; wrapMode: Text.Wrap; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
  }
  Flow {
    width: parent.width
    spacing: ui.px(6)
    visible: root.picked.length > 0
    Repeater {
      model: root.picked
      delegate: Rectangle {
        required property var modelData
        width: pickText.implicitWidth + ui.px(34); height: ui.px(24); radius: height / 2
        color: root.c.sel
        border.width: 1
        border.color: root.c.accent
        Text { textFormat: Text.PlainText; id: pickText; anchors.left: parent.left; anchors.leftMargin: ui.px(10); anchors.verticalCenter: parent.verticalCenter; text: modelData.name || modelData.id; color: root.c.accent; font.family: ui.sans; font.pixelSize: ui.f11 }
        Icon { anchors.right: parent.right; anchors.rightMargin: ui.px(8); anchors.verticalCenter: parent.verticalCenter; name: "x"; size: ui.px(11); color: root.c.accent }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle(parent.modelData) }
      }
    }
  }
  Text { textFormat: Text.PlainText; width: parent.width; visible: root.errorText !== "" || root.doneText !== ""; wrapMode: Text.Wrap; text: root.errorText !== "" ? root.errorText : root.doneText; color: root.errorText !== "" ? root.c.bad : root.c.ok; font.family: ui.sans; font.pixelSize: ui.f11 }
  PillButton { c: root.c; width: parent.width; label: root.busy ? "Sending…" : (root.picked.length > 1 ? "Send " + root.picked.length + " invitations" : "Send invitation"); primary: true; enabled: !root.busy && root.picked.length > 0; onClicked: root.send() }
}

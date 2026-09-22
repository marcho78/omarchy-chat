import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// New room: a name, an optional topic, encrypted and private by default.
Modal {
  id: root
  property var service: null
  signal created(var room)
  icon: "plus-circle"
  title: "New room"
  description: "End-to-end encrypted and private by default."
  dialogWidth: ui.px(440)
  Ui { id: ui }

  property bool encrypted: true
  property bool isPrivate: true
  property bool busy: false
  property string errorText: ""
  readonly property bool hasTextFocus: nameField.hasFocus || topicField.hasFocus
  onOpenChanged: if (open) { nameField.text = ""; topicField.text = ""; encrypted = true; isPrivate = true; errorText = ""; Qt.callLater(function() { nameField.forceActiveFocus() }) }

  function create() {
    var name = nameField.text.trim()
    if (name === "" || root.busy) return
    root.busy = true; root.errorText = ""
    var topic = topicField.text.trim()
    root.service.createRoom(name, root.encrypted, root.isPrivate, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not create the room"; return }
      if (topic !== "") root.service.setRoomTopic(r.result.id, topic, function() {})
      root.created(r.result)
      root.close()
    })
  }

  component ToggleCard: Rectangle {
    property string icon: ""
    property color tone: root.c.accent
    property string label: ""
    property string detail: ""
    property bool on: true
    signal toggled()
    width: parent.width
    height: ui.px(62)
    radius: ui.px(9)
    color: root.c.bg
    border.width: 1
    border.color: root.c.line
    Icon { id: cardIcon; anchors.left: parent.left; anchors.leftMargin: ui.px(13); anchors.verticalCenter: parent.verticalCenter; name: parent.icon; size: ui.px(18); color: parent.tone }
    Column {
      anchors.left: cardIcon.right
      anchors.leftMargin: ui.px(13)
      anchors.right: cardToggle.left
      anchors.rightMargin: ui.px(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: ui.px(2)
      Text { text: parent.parent.label; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.DemiBold }
      Text { width: parent.width; text: parent.parent.detail; color: root.c.muted; wrapMode: Text.Wrap; font.family: ui.sans; font.pixelSize: ui.f11 }
    }
    Toggle { id: cardToggle; anchors.right: parent.right; anchors.rightMargin: ui.px(13); anchors.verticalCenter: parent.verticalCenter; c: root.c; checked: parent.on; onToggled: parent.toggled() }
  }

  Column {
    width: parent.width
    spacing: ui.px(6)
    Text { text: "Name"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11; font.weight: Font.Medium }
    Field { id: nameField; c: root.c; width: parent.width; height: ui.px(40); placeholder: "Omarchy Theming"; maximumLength: 256; onAccepted: topicField.forceActiveFocus(); onEscaped: root.close() }
  }
  Column {
    width: parent.width
    spacing: ui.px(6)
    Text { textFormat: Text.StyledText; text: "Topic <font color=\"" + root.c.muted + "\">· optional</font>"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11; font.weight: Font.Medium }
    Field { id: topicField; c: root.c; width: parent.width; height: ui.px(40); placeholder: "What the room is for"; maximumLength: 2000; onAccepted: root.create(); onEscaped: root.close() }
  }
  ToggleCard { icon: "lock-simple"; tone: root.c.ok; label: "End-to-end encrypted"; detail: "Only members can read it, not even the server. Cannot be turned off later."; on: root.encrypted; onToggled: root.encrypted = !root.encrypted }
  ToggleCard { icon: "eye-slash"; tone: root.c.accent; label: "Private"; detail: "Invite only. Off makes it public: anyone can find and join it."; on: root.isPrivate; onToggled: root.isPrivate = !root.isPrivate }
  Text { width: parent.width; visible: root.errorText !== ""; wrapMode: Text.Wrap; text: root.errorText; color: root.c.bad; font.family: ui.sans; font.pixelSize: ui.f11 }
  Row {
    width: parent.width
    spacing: ui.px(9)
    PillButton { c: root.c; width: parent.width - ui.px(100) - parent.spacing; label: root.busy ? "Creating…" : "Create room"; primary: true; enabled: !root.busy && nameField.text.trim() !== ""; onClicked: root.create() }
    PillButton { c: root.c; width: ui.px(100); label: "Cancel"; enabled: !root.busy; onClicked: root.close() }
  }
}

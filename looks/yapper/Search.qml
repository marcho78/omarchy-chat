import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// Message search: the server for unencrypted rooms, a local scan of the
// decrypted history for the encrypted ones. Scoped to every room or
// the open one.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string query: ""
  property string scope: ""             // "" = all rooms, else a room id
  property string scopeName: ""
  signal openMessage(string roomId, string eventId)
  signal closeRequested()
  Ui { id: ui }

  property var hits: []
  property var stats: null
  property bool searching: false
  property string lastQuery: ""
  property string errorText: ""
  readonly property bool hasTextFocus: field.hasFocus
  function focusField() { field.forceActiveFocus(); field.selectAll() }
  onQueryChanged: if (field.text !== query) field.text = query
  onVisibleChanged: if (visible) Qt.callLater(focusField)

  function run() {
    var q = field.text.trim()
    if (q === "" || root.searching) return
    root.searching = true; root.errorText = ""; root.lastQuery = q
    root.service.searchMessages(q, root.scope, function(r) {
      root.searching = false
      if (!r.ok || !r.result) { root.errorText = r.ok ? "Search returned nothing" : (r.error || "Search failed"); root.hits = []; root.stats = null; return }
      root.hits = r.result.hits || []
      root.stats = r.result
    })
  }
  function reset() { field.text = ""; root.hits = []; root.stats = null; root.lastQuery = ""; root.errorText = "" }

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: scopes.y + scopes.height + ui.px(14)
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
    Rectangle {
      id: box
      anchors.left: parent.left
      anchors.leftMargin: ui.px(24)
      anchors.top: parent.top
      anchors.topMargin: ui.px(18)
      width: Math.min(parent.width - ui.px(96), ui.px(560))
      height: ui.px(40)
      radius: ui.px(9)
      color: root.c.bg2
      border.width: 1
      border.color: root.c.accent
      Icon { id: boxIcon; anchors.left: parent.left; anchors.leftMargin: ui.px(13); anchors.verticalCenter: parent.verticalCenter; name: "magnifying-glass"; size: ui.px(16); color: root.c.accent }
      TextInput {
        id: field
        anchors.left: boxIcon.right
        anchors.leftMargin: ui.px(9)
        anchors.right: escKey.left
        anchors.rightMargin: ui.px(9)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: root.c.fg
        selectionColor: root.c.sel
        selectedTextColor: root.c.fg
        maximumLength: 200
        font.family: ui.sans; font.pixelSize: ui.f14
        readonly property bool hasFocus: activeFocus
        onAccepted: root.run()
        Keys.onEscapePressed: function(event) { event.accepted = true; if (text !== "") root.reset(); else root.closeRequested() }
        Text { anchors.fill: parent; visible: field.text === ""; text: root.scope !== "" ? "Search in " + root.scopeName : "Search rooms and messages"; color: root.c.muted; font: field.font; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
      }
      Rectangle {
        id: escKey
        anchors.right: parent.right
        anchors.rightMargin: ui.px(11)
        anchors.verticalCenter: parent.verticalCenter
        width: escText.implicitWidth + ui.px(10); height: ui.px(18); radius: ui.px(4)
        color: "transparent"
        border.width: 1
        border.color: root.c.line
        Text { id: escText; anchors.centerIn: parent; text: "Esc"; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
      }
    }
    IconButton { anchors.right: parent.right; anchors.rightMargin: ui.px(16); anchors.top: parent.top; anchors.topMargin: ui.px(22); c: root.c; tips: root.tips; icon: "x"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Back to chat (Esc)"; onClicked: root.closeRequested() }
    // Scope chips
    Flow {
      id: scopes
      anchors.left: parent.left
      anchors.leftMargin: ui.px(24)
      anchors.right: parent.right
      anchors.rightMargin: ui.px(24)
      anchors.top: box.bottom
      anchors.topMargin: ui.px(11)
      spacing: ui.px(7)
      Repeater {
        model: root.scopeName !== "" ? [{ value: "", label: "All rooms" }, { value: root.scope !== "" ? root.scope : "__current", label: root.scopeName + " only" }] : [{ value: "", label: "All rooms" }]
        delegate: Rectangle {
          required property var modelData
          readonly property bool on: (root.scope === "" && modelData.value === "") || (root.scope !== "" && modelData.value === root.scope)
          width: chipText.implicitWidth + ui.px(24); height: ui.px(28); radius: height / 2
          color: on ? root.c.sel : (chipMouse.containsMouse ? root.c.hover : "transparent")
          border.width: 1
          border.color: on ? root.c.accent : root.c.line
          Text { textFormat: Text.PlainText; id: chipText; anchors.centerIn: parent; text: parent.modelData.label; color: parent.on ? root.c.accent : root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
          MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (parent.modelData.value === "__current") return; root.scope = parent.modelData.value; if (root.lastQuery !== "") root.run() } }
        }
      }
    }
  }

  Flickable {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: ui.px(20)
    anchors.rightMargin: ui.px(20)
    anchors.topMargin: ui.px(12)
    contentHeight: hitColumn.implicitHeight + ui.px(24)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    Column {
      id: hitColumn
      width: parent.width
      spacing: ui.px(7)
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        bottomPadding: ui.px(6)
        text: root.searching ? "Searching…"
          : root.errorText !== "" ? root.errorText
          : root.stats ? root.hits.length + (root.hits.length === 1 ? " hit" : " hits") + " for “" + root.lastQuery + "” · server search for " + root.stats.server_rooms + " unencrypted room" + (root.stats.server_rooms === 1 ? "" : "s") + ", a local scan of " + Number(root.stats.scanned_messages).toLocaleString(Qt.locale(), "f", 0) + " decrypted messages in " + root.stats.scanned_rooms + " encrypted"
          : "Type what you remember and press Enter. Encrypted rooms are searched on this machine; nothing leaves it."
        color: root.errorText !== "" ? root.c.bad : root.c.muted
        lineHeight: 1.3
        font.family: ui.sans; font.pixelSize: ui.f11
      }
      Repeater {
        model: root.hits
        delegate: Rectangle {
          id: hit
          required property var modelData
          readonly property bool mine: root.service && modelData.sender === root.service.userId
          readonly property color who: mine ? root.c.accent : Palettes.colorOf(modelData.sender, root.c.light)
          width: parent.width
          height: hitInner.implicitHeight + ui.px(26)
          radius: ui.px(9)
          color: hitMouse.containsMouse ? root.c.hover : root.c.bg2
          border.width: 1
          border.color: hitMouse.containsMouse ? root.c.accent : root.c.line
          Column {
            id: hitInner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ui.px(13)
            anchors.leftMargin: ui.px(15)
            anchors.rightMargin: ui.px(15)
            spacing: ui.px(7)
            Row {
              width: parent.width
              spacing: ui.px(8)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: "hash"; size: ui.px(12); color: root.c.muted }
              Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; width: parent.width - ui.px(100); elide: Text.ElideRight; text: hit.modelData.room_name; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.DemiBold }
              Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: Format.timeOf(Number(hit.modelData.ts)); color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
            }
            Row {
              width: parent.width
              spacing: ui.px(10)
              Avatar { service: root.service; userId: hit.modelData.sender; name: hit.modelData.sender_name; size: ui.px(26); fallbackColor: hit.who; initialColor: root.c.bg2; fontFamily: ui.sans }
              Column {
                width: parent.width - ui.px(36)
                spacing: ui.px(2)
                Text { textFormat: Text.PlainText; text: hit.mine ? "You" : hit.modelData.sender_name; color: hit.who; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.DemiBold }
                Text {
                  width: parent.width
                  textFormat: Text.StyledText
                  text: Format.highlightMatch(hit.modelData.body, root.lastQuery, root.c.accent)
                  color: root.c.fg
                  wrapMode: Text.Wrap
                  maximumLineCount: 4
                  elide: Text.ElideRight
                  lineHeight: 1.3
                  font.family: ui.sans; font.pixelSize: ui.px(12.5)
                }
              }
            }
          }
          MouseArea { id: hitMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openMessage(hit.modelData.room, hit.modelData.event_id) }
        }
      }
    }
  }
}

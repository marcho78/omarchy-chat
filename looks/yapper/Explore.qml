import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// The public room directory: the homeserver's list, most joined first,
// narrowed by what you type; Join or Open on each room; Load more.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string query: ""
  signal roomChosen(var room)
  signal closeRequested()
  Ui { id: ui }

  property var rooms: []
  property string server: ""
  property int total: 0
  property string next: ""
  property bool loading: false
  property bool joining: false
  property string errorText: ""
  readonly property bool hasTextFocus: field.hasFocus
  function focusField() { field.forceActiveFocus(); field.selectAll() }

  onQueryChanged: { if (field.text !== query) field.text = query; debounce.restart() }
  onVisibleChanged: if (visible && root.rooms.length === 0 && !root.loading) root.load(false)
  Timer { id: debounce; interval: 350; onTriggered: root.load(false) }

  // Empty text lists the directory page by page; text asks the server
  // to search it.
  function load(more) {
    if (!root.service || root.loading) return
    root.loading = true; root.errorText = ""
    var q = field.text.trim()
    if (q !== "") {
      root.service.searchRooms(q, function(r) {
        root.loading = false
        if (field.text.trim() !== q) return
        if (!r.ok) { root.errorText = r.error || "Search failed"; return }
        root.rooms = r.result; root.next = ""; root.total = r.result.length
        if (r.result.length === 0) root.errorText = "No public rooms match \"" + q + "\""
      })
      return
    }
    root.service.explore(more ? root.next : "", function(r) {
      root.loading = false
      if (field.text.trim() !== "") return
      if (!r.ok) { root.errorText = r.error || "Could not read the directory"; return }
      root.server = r.result.server || ""
      root.total = Number(r.result.total) || 0
      root.next = r.result.next || ""
      root.rooms = more ? root.rooms.concat(r.result.rooms) : r.result.rooms
      if (root.rooms.length === 0) root.errorText = "The directory is empty"
    })
  }
  function join(room) {
    if (root.joining) return
    root.joining = true; root.errorText = ""
    root.service.join(room.id, function(r) {
      root.joining = false
      if (!r.ok) { root.errorText = r.error || "Could not join"; return }
      root.roomChosen(r.result)
    })
  }
  function open(room) {
    var r = root.service.roomById(room.id)
    if (r) root.roomChosen(r); else root.join(room)
  }

  // Header
  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: field.y + field.height + ui.px(14)
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
    Flow {
      id: titleRow
      anchors.left: parent.left
      anchors.leftMargin: ui.px(24)
      anchors.right: parent.right
      anchors.rightMargin: ui.px(64)
      anchors.top: parent.top
      anchors.topMargin: ui.px(18)
      spacing: ui.px(10)
      Icon { name: "compass"; size: ui.px(19); color: root.c.accent }
      Text { text: "Explore"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f18; font.weight: Font.DemiBold; font.letterSpacing: -0.3 }
      Text { height: ui.px(24); verticalAlignment: Text.AlignVCenter; text: "public directory of"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f12 }
      Rectangle {
        width: serverText.implicitWidth + ui.px(20); height: ui.px(24); radius: height / 2
        color: root.c.chip
        Text { id: serverText; anchors.centerIn: parent; text: root.server !== "" ? root.server : "your homeserver"; color: root.c.fg; font.family: ui.mono; font.pixelSize: ui.f11 }
      }
    }
    IconButton { anchors.right: parent.right; anchors.rightMargin: ui.px(16); anchors.top: parent.top; anchors.topMargin: ui.px(14); c: root.c; tips: root.tips; icon: "x"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Back to chat (Esc)"; onClicked: root.closeRequested() }
    Field {
      id: field
      c: root.c
      anchors.left: parent.left
      anchors.leftMargin: ui.px(24)
      anchors.top: titleRow.bottom
      anchors.topMargin: ui.px(12)
      width: Math.min(parent.width - ui.px(48), ui.px(460))
      height: ui.px(38)
      color: root.c.bg2
      icon: "magnifying-glass"
      placeholder: "Narrow the list — empty lists everything, most joined first"
      maximumLength: 120
      onTextChanged: { root.errorText = ""; debounce.restart() }
      onAccepted: { debounce.stop(); root.load(false) }
      onEscaped: { if (text !== "") text = ""; else root.closeRequested() }
    }
  }

  // Rooms
  Flickable {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: ui.px(16)
    anchors.rightMargin: ui.px(16)
    anchors.topMargin: ui.px(12)
    contentHeight: listColumn.implicitHeight + ui.px(24)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    Column {
      id: listColumn
      width: parent.width
      spacing: ui.px(7)
      Repeater {
        model: root.rooms
        delegate: Rectangle {
          id: card
          required property var modelData
          readonly property bool joined: modelData.joined === true || (root.service && root.service.roomById(modelData.id) !== null)
          width: parent.width
          height: ui.px(68)
          radius: ui.px(9)
          color: root.c.bg2
          border.width: 1
          border.color: cardMouse.containsMouse ? root.c.accent : root.c.line
          MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
          Avatar {
            id: cardAvatar
            anchors.left: parent.left
            anchors.leftMargin: ui.px(15)
            anchors.verticalCenter: parent.verticalCenter
            service: root.service
            mxc: card.modelData.avatar || ""
            name: card.modelData.name
            userId: card.modelData.id
            size: ui.px(40)
            radius: ui.px(11)
            fallbackColor: Palettes.colorOf(card.modelData.alias || card.modelData.id, root.c.light)
            initialColor: root.c.bg2
            fontFamily: ui.sans
          }
          Column {
            anchors.left: cardAvatar.right
            anchors.leftMargin: ui.px(13)
            anchors.right: membersText.left
            anchors.rightMargin: ui.px(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: ui.px(2)
            Row {
              width: parent.width
              spacing: ui.px(7)
              Text { anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, parent.width * 0.6); elide: Text.ElideRight; text: card.modelData.name; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(13.5); font.weight: Font.DemiBold }
              Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - x; elide: Text.ElideRight; text: card.modelData.alias || card.modelData.id; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
            }
            Text { width: parent.width; text: card.modelData.topic ? Format.oneLine(card.modelData.topic) : "No topic"; color: root.c.muted; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.f12 }
          }
          Text {
            id: membersText
            anchors.right: actionButton.left
            anchors.rightMargin: ui.px(14)
            anchors.verticalCenter: parent.verticalCenter
            text: Number(card.modelData.members).toLocaleString(Qt.locale(), "f", 0)
            color: root.c.muted
            font.family: ui.mono; font.pixelSize: ui.f11
          }
          PillButton {
            id: actionButton
            c: root.c
            anchors.right: parent.right
            anchors.rightMargin: ui.px(15)
            anchors.verticalCenter: parent.verticalCenter
            label: card.joined ? "Open" : (root.joining ? "…" : "Join")
            primary: !card.joined
            round: true
            enabled: !root.joining
            onClicked: card.joined ? root.open(card.modelData) : root.join(card.modelData)
          }
        }
      }
      Text {
        width: parent.width
        visible: root.errorText !== ""
        topPadding: ui.px(8)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.errorText
        color: root.c.bad
        font.family: ui.sans; font.pixelSize: ui.f12
      }
      Text {
        width: parent.width
        visible: root.loading && root.rooms.length === 0
        topPadding: ui.px(24)
        horizontalAlignment: Text.AlignHCenter
        text: "Reading the directory…"
        color: root.c.muted
        font.family: ui.sans; font.pixelSize: ui.f12
      }
      Rectangle {
        width: parent.width
        visible: root.next !== "" && field.text.trim() === ""
        height: ui.px(42)
        radius: ui.px(9)
        color: moreMouse.containsMouse ? root.c.hover : "transparent"
        border.width: 1
        border.color: moreMouse.containsMouse ? root.c.accent : root.c.line
        Text { anchors.centerIn: parent; text: root.loading ? "Loading…" : "Load more" + (root.total > root.rooms.length ? " · " + (root.total - root.rooms.length) + " to go" : ""); color: moreMouse.containsMouse ? root.c.accent : root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(12.5) }
        MouseArea { id: moreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.loading; onClicked: root.load(true) }
      }
    }
  }
}

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Format.js" as Format

// Message search. Scope is one room or everything; results open the room
// at the message. Encrypted rooms are scanned locally through recent
// history, which the footer says plainly.
Item {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property string roomId: ""         // scope when `inRoom`
  property string roomName: ""
  property bool inRoom: roomId !== ""

  property var hits: []
  property var stats: null
  property bool searching: false
  property string lastQuery: ""
  property string errorText: ""

  signal closeRequested()
  signal openMessage(string roomId, string eventId)

  readonly property bool hasTextFocus: field.activeFocus
  readonly property color accent: service ? service.accent : Color.accent

  function focusField() { field.forceActiveFocus(); field.selectAll() }
  // Focus cannot be taken while the pane is still hidden; take it once shown.
  onVisibleChanged: if (visible) Qt.callLater(focusField)
  function run() {
    var q = field.text.trim()
    if (q === "" || root.searching) return
    root.searching = true
    root.errorText = ""
    root.lastQuery = q
    root.service.searchMessages(q, root.inRoom ? root.roomId : "", function(r) {
      root.searching = false
      if (!r.ok) { root.errorText = r.error || "Search failed"; root.hits = []; root.stats = null; return }
      root.hits = r.result.hits
      root.stats = r.result
    })
  }
  function reset() { field.text = ""; root.hits = []; root.stats = null; root.lastQuery = ""; root.errorText = "" }

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    // Field + scope
    Row {
      width: parent.width
      spacing: Style.spacing.controlGap
      TextField {
        id: field
        width: parent.width - goButton.width - scopeButton.width - closeButton.width - 3 * Style.spacing.controlGap
        placeholderText: root.inRoom ? "Search in " + root.roomName : "Search all rooms"
        maximumLength: 256
        enabled: !root.searching
        onAccepted: root.run()
      }
      Button {
        id: scopeButton
        text: root.inRoom ? "This room" : "All rooms"
        iconText: root.inRoom ? "󰭹" : "󰊫"
        onClicked: { root.inRoom = !root.inRoom; if (root.lastQuery !== "") root.run() }
      }
      Button { id: goButton; text: root.searching ? "…" : "Search"; iconText: "󰍉"; bordered: true; enabled: !root.searching; onClicked: root.run() }
      Button { id: closeButton; iconText: "󰅖"; text: ""; onClicked: root.closeRequested() }
    }

    // Status line
    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      visible: root.errorText !== "" || root.stats !== null || root.searching
      text: {
        if (root.errorText !== "") return root.errorText
        if (root.searching) return "Searching…"
        if (!root.stats) return ""
        var parts = [root.hits.length + (root.hits.length === 1 ? " result" : " results") + " for “" + root.lastQuery + "”"]
        if (root.stats.server_rooms > 0) parts.push(root.stats.server_rooms + " room" + (root.stats.server_rooms === 1 ? "" : "s") + " searched on the server")
        if (root.stats.scanned_rooms > 0) parts.push(root.stats.scanned_rooms + " encrypted room" + (root.stats.scanned_rooms === 1 ? "" : "s") + " scanned locally — the last " + root.stats.scanned_messages + " messages")
        return parts.join("  ·  ")
      }
      color: root.errorText !== "" ? Color.urgent : root.fg
      opacity: root.errorText !== "" ? 1 : 0.6
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }

    ListView {
      id: list
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: Style.space(4)
      model: root.hits
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: Item {
        id: hit
        required property var modelData
        width: list.width
        implicitHeight: hitCol.implicitHeight + Style.space(16)
        Rectangle {
          anchors.fill: parent
          radius: Style.space(8)
          color: hitMouse.containsMouse ? (root.service ? root.service.hover : "transparent") : Util.alpha(root.fg, 0.04)
        }
        Column {
          id: hitCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(10)
          spacing: Style.space(3)
          Row {
            width: parent.width
            spacing: Style.space(8)
            Text {
              text: hit.modelData.sender_name
              color: Qt.hsla(Format.hueFor(hit.modelData.sender) / 360, 0.6, 0.62, 1)
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
            }
            Text {
              visible: !root.inRoom
              text: "in " + hit.modelData.room_name
              color: root.fg; opacity: 0.6
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
            Text {
              text: Format.dayLabel(hit.modelData.ts, Date.now()) + " " + Qt.formatTime(new Date(hit.modelData.ts), "HH:mm")
              color: root.fg; opacity: 0.45
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
          }
          Text {
            width: parent.width
            textFormat: Text.RichText
            text: Format.highlightMatch(hit.modelData.body, root.lastQuery, root.accent)
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
        }
        MouseArea {
          id: hitMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openMessage(hit.modelData.room, hit.modelData.event_id)
        }
      }
      Text {
        anchors.centerIn: parent
        visible: root.stats !== null && root.hits.length === 0 && !root.searching
        text: "Nothing found"
        color: root.fg; opacity: 0.5
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
    }
  }
}

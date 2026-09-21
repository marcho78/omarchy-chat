import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Format.js" as Format

// Room details and members. Used as the window's side pane and the popup's
// members view. Set `roomId` to load; `close()` clears.
Item {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property string roomId: ""
  property bool compact: false

  property var details: null
  property var members: []
  property bool loading: false
  property string errorText: ""

  signal closeRequested()
  signal memberChosen(var member)

  readonly property bool hasTextFocus: search.activeFocus
  readonly property color accent: service ? service.accent : Color.accent

  onRoomIdChanged: reload()
  function reload() {
    root.details = null
    root.members = []
    root.errorText = ""
    if (!root.roomId || !root.service) return
    root.loading = true
    var id = root.roomId
    root.service.roomDetails(id, function(r) {
      if (root.roomId !== id) return
      if (!r.ok) { root.loading = false; root.errorText = r.error || "Could not load the room"; return }
      root.details = r.result
      root.loadMembers()
    })
  }
  function loadMembers() {
    var id = root.roomId
    root.service.members(id, search.text, 300, function(r) {
      if (root.roomId !== id) return
      root.loading = false
      if (!r.ok) { root.errorText = r.error || "Could not load members"; return }
      root.members = r.result
    })
  }
  Timer { id: searchDebounce; interval: 250; onTriggered: root.loadMembers() }

  Column {
    id: column
    anchors.fill: parent
    spacing: Style.space(10)

    // Header: avatar, name, close
    Item {
      width: parent.width
      implicitHeight: Math.max(headerCol.implicitHeight, Style.space(48))
      Avatar {
        id: roomAvatar
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        size: Style.space(48)
        userId: root.roomId
        name: root.details ? root.details.name : ""
        mxc: root.details && root.details.avatar ? root.details.avatar : ""
        service: root.service
        fontFamily: root.fontFamily
      }
      Column {
        id: headerCol
        anchors.left: roomAvatar.right
        anchors.leftMargin: Style.space(12)
        anchors.right: closeButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Text {
          width: parent.width
          text: root.details ? root.details.name : "Room"
          color: root.fg
          font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: {
            if (!root.details) return root.loading ? "Loading…" : ""
            var d = root.details
            var bits = [d.member_count + " member" + (d.member_count === 1 ? "" : "s")]
            bits.push(d.encrypted ? "󰌾 encrypted" : "󰌿 not encrypted")
            bits.push(d.join_rule === "public" ? "public" : d.join_rule === "invite" ? "invite only" : d.join_rule)
            return bits.join("  ·  ")
          }
          color: root.fg; opacity: 0.6
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
      Button {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰅖"
        text: ""
        onClicked: root.closeRequested()
      }
    }

    // Topic + alias
    Text {
      width: parent.width
      visible: root.details && !!root.details.topic
      wrapMode: Text.WordWrap
      maximumLineCount: root.compact ? 3 : 6
      elide: Text.ElideRight
      text: root.details ? Format.oneLine(root.details.topic) : ""
      color: root.fg; opacity: 0.8
      font.family: root.fontFamily; font.pixelSize: Style.font.body
    }
    Row {
      visible: root.details && !!root.details.alias
      spacing: Style.space(6)
      Text {
        text: root.details ? root.details.alias : ""
        color: root.accent
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
      Text {
        text: "󰆏"
        color: root.fg; opacity: 0.5
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.service.copyText(root.details.alias) }
      }
    }

    PanelSeparator { width: parent.width }

    // Members
    Item {
      width: parent.width
      implicitHeight: search.implicitHeight
      PanelSectionHeader { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Members" + (root.details ? " · " + root.details.member_count : "") }
      TextField {
        id: search
        anchors.right: parent.right
        width: Math.min(parent.width * 0.55, Style.space(220))
        placeholderText: "Filter"
        maximumLength: 64
        onTextChanged: searchDebounce.restart()
      }
    }

    Text {
      width: parent.width
      visible: root.errorText !== ""
      wrapMode: Text.WordWrap
      text: root.errorText
      color: Color.urgent
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }

    ListView {
      id: list
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: Style.space(2)
      model: root.members
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: Item {
        id: row
        required property var modelData
        width: list.width
        implicitHeight: Style.space(40)
        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: mMouse.containsMouse ? (root.service ? root.service.hover : "transparent") : "transparent"
        }
        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(10)
          Avatar {
            anchors.verticalCenter: parent.verticalCenter
            size: Style.space(28)
            userId: row.modelData.id
            name: row.modelData.name
            mxc: row.modelData.avatar || ""
            service: root.service
            fontFamily: root.fontFamily
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(28) - Style.space(10) - (roleBadge.visible ? roleBadge.width + Style.space(10) : 0)
            spacing: 0
            Text {
              width: parent.width
              text: row.modelData.name
              color: root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: row.modelData.id
              color: root.fg; opacity: 0.45
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
            }
          }
          Rectangle {
            id: roleBadge
            anchors.verticalCenter: parent.verticalCenter
            visible: row.modelData.role !== "member"
            width: roleText.implicitWidth + Style.space(10)
            height: Style.space(18)
            radius: Style.space(4)
            color: Util.alpha(root.accent, 0.18)
            border.width: 1
            border.color: root.accent
            Text {
              id: roleText
              anchors.centerIn: parent
              text: row.modelData.role === "admin" ? "Admin" : "Mod"
              color: root.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true
            }
          }
        }
        MouseArea {
          id: mMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.memberChosen(row.modelData)
        }
      }
      Text {
        anchors.centerIn: parent
        visible: root.members.length === 0 && !root.loading && root.details !== null
        text: search.text !== "" ? "No one matches" : "No members loaded"
        color: root.fg; opacity: 0.5
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
    }
  }
}

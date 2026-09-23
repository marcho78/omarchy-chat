import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// One room in the sidebar: picture, name with its lock, the draft or the
// topic underneath, and on the right the last activity, the unread badge
// or the muted bell.
Item {
  id: root
  property var c: Palettes.fallback()
  property var service: null
  property var room: null
  property bool active: false
  signal chosen()
  Ui { id: ui }

  readonly property bool muted: room ? room.notification_mode === "mute" : false
  readonly property int unread: room && !muted ? (Number(room.unread) || 0) : 0
  readonly property bool highlighted: room ? (Number(room.highlights) || 0) > 0 : false
  readonly property bool direct: room ? room.direct === true : false
  readonly property string draft: service && room ? service.draft(room.id) : ""
  readonly property string preview: draft !== "" ? draft
    : room && room.topic ? Format.oneLine(room.topic)
    : direct ? "Direct message" : ""
  readonly property string when: room && room.last_activity ? Format.timeOf(Number(room.last_activity)) : ""
  readonly property var bridge: room ? room.bridge : null

  function bridgeIcon(protocol) {
    switch (String(protocol || "")) {
      case "whatsapp": return "whatsapp-logo"
      case "discord": return "discord-logo"
      case "slack": return "slack-logo"
      case "telegram": return "telegram-logo"
      case "instagram": return "instagram-logo"
      case "facebook": return "facebook-logo"
      case "messenger": return "messenger-logo"
      case "signal": return "chat-circle-dots"
      default: return "plugs-connected"
    }
  }

  height: ui.px(46)

  Rectangle {
    anchors.fill: parent
    radius: ui.px(8)
    color: root.active ? root.c.sel : (mouse.containsMouse ? root.c.hover : "transparent")
  }
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: ui.px(9)
    anchors.bottomMargin: ui.px(9)
    width: ui.px(2.5)
    radius: ui.px(3)
    color: root.c.accent
    visible: root.active
  }

  Avatar {
    id: picture
    anchors.left: parent.left
    anchors.leftMargin: ui.px(9)
    anchors.verticalCenter: parent.verticalCenter
    service: root.service
    mxc: root.room && root.room.avatar ? root.room.avatar : ""
    name: root.room ? root.room.name : ""
    userId: root.room ? root.room.id : ""
    size: ui.px(30)
    radius: root.direct ? size / 2 : ui.px(9)
    fallbackColor: root.direct ? Palettes.colorOf(root.room ? root.room.id : "", root.c.light) : root.c.surface
    initialColor: root.direct ? root.c.bg2 : root.c.fg
    fontFamily: ui.sans
    // A bridged room wears the network's logo.
    Rectangle {
      visible: root.bridge !== null && root.bridge !== undefined
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: -ui.px(3)
      anchors.bottomMargin: -ui.px(3)
      width: ui.px(14)
      height: ui.px(14)
      radius: width / 2
      color: root.c.bg2
      Icon { anchors.centerIn: parent; name: root.bridgeIcon(root.bridge ? root.bridge.protocol : ""); size: ui.px(9); color: root.c.ok }
    }
  }

  Column {
    anchors.left: picture.right
    anchors.leftMargin: ui.px(9)
    anchors.right: side.left
    anchors.rightMargin: ui.px(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: ui.px(1)
    Row {
      width: parent.width
      spacing: ui.px(5)
      Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.room ? root.room.encrypted === true : false
        name: "lock-simple"; weight: "fill"
        size: ui.px(9.5)
        color: root.c.ok
      }
      Text {
        textFormat: Text.PlainText
        width: parent.width - (root.room && root.room.encrypted === true ? ui.px(9.5) + parent.spacing : 0)
        text: root.room ? root.room.name : ""
        color: root.muted ? root.c.muted : root.c.fg
        elide: Text.ElideRight
        font.family: ui.sans
        font.pixelSize: ui.f13
        font.weight: root.unread > 0 ? Font.DemiBold : Font.Medium
      }
    }
    Row {
      width: parent.width
      spacing: ui.px(4)
      Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.draft !== ""
        name: "pencil-simple"
        size: ui.px(10)
        color: root.c.warn
      }
      Text {
        textFormat: Text.PlainText
        width: parent.width - (root.draft !== "" ? ui.px(10) + parent.spacing : 0)
        text: root.preview
        color: root.c.muted
        elide: Text.ElideRight
        font.family: ui.sans
        font.pixelSize: ui.f11
      }
    }
  }

  Column {
    id: side
    anchors.right: parent.right
    anchors.rightMargin: ui.px(9)
    anchors.verticalCenter: parent.verticalCenter
    spacing: ui.px(3)
    Text {
      anchors.right: parent.right
      text: root.when
      color: root.c.muted
      font.family: ui.mono
      font.pixelSize: ui.f10
      visible: text !== ""
    }
    Rectangle {
      anchors.right: parent.right
      visible: root.unread > 0
      width: Math.max(ui.px(18), badge.implicitWidth + ui.px(10))
      height: ui.px(17)
      radius: height / 2
      color: root.highlighted ? root.c.bad : root.c.accent
      Text {
        id: badge
        anchors.centerIn: parent
        text: root.unread > 99 ? "99+" : String(root.unread)
        color: root.c.bg2
        font.family: ui.mono
        font.pixelSize: ui.f10
        font.bold: true
      }
    }
    Icon {
      anchors.right: parent.right
      visible: root.muted
      name: "bell-slash"
      size: ui.px(11)
      color: root.c.muted
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.chosen()
  }
}

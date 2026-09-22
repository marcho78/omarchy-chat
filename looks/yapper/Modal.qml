import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// A dialog over the window: scrim, a card with an icon, title and line
// of explanation, a close button, and whatever the dialog puts in
// `content`. Esc and the scrim close it.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property bool open: false
  property string icon: "info"
  property string iconWeight: "regular"
  property color tone: root.c.accent
  property color iconBg: root.c.sel
  property color ring: root.c.line
  property string title: ""
  property string description: ""
  property real dialogWidth: ui.px(480)
  default property alias content: contentColumn.data
  signal closed()
  Ui { id: ui }

  anchors.fill: parent
  visible: open
  z: 50
  function close() { root.open = false; root.closed() }
  // Keys not taken by a field inside bubble up here.
  onOpenChanged: if (open) Qt.callLater(function() { if (!root.activeFocus && root.open) root.forceActiveFocus() })

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.55)
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.close() }
  }
  Keys.onEscapePressed: function(event) { event.accepted = true; root.close() }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(root.dialogWidth, parent.width - ui.px(64))
    height: Math.min(header.height + contentColumn.implicitHeight + ui.px(38), parent.height - ui.px(64))
    radius: ui.px(13)
    color: root.c.bg2
    border.width: 1
    border.color: root.ring
    clip: true
    // Clicks inside stay inside.
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: function(m) { m.accepted = true } }
    opacity: root.open ? 1 : 0
    scale: root.open ? 1 : 0.98
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Item {
      id: header
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: headerText.implicitHeight + ui.px(34)
      Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
      Rectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.leftMargin: ui.px(20)
        anchors.top: parent.top
        anchors.topMargin: ui.px(19)
        width: ui.px(38); height: ui.px(38); radius: ui.px(11)
        color: root.iconBg
        Icon { anchors.centerIn: parent; name: root.icon; weight: root.iconWeight; size: ui.px(20); color: root.tone }
      }
      Column {
        id: headerText
        anchors.left: iconTile.right
        anchors.leftMargin: ui.px(13)
        anchors.right: closeButton.left
        anchors.rightMargin: ui.px(10)
        anchors.top: parent.top
        anchors.topMargin: ui.px(19)
        spacing: ui.px(3)
        Text { width: parent.width; text: root.title; color: root.c.fg; wrapMode: Text.Wrap; font.family: ui.sans; font.pixelSize: ui.px(15.5); font.weight: Font.DemiBold; font.letterSpacing: -0.2 }
        Text { width: parent.width; text: root.description; color: root.c.muted; wrapMode: Text.Wrap; lineHeight: 1.3; font.family: ui.sans; font.pixelSize: ui.px(12.5) }
      }
      IconButton { id: closeButton; anchors.right: parent.right; anchors.rightMargin: ui.px(16); anchors.top: parent.top; anchors.topMargin: ui.px(19); c: root.c; tips: root.tips; icon: "x"; size: ui.px(30); iconSize: ui.px(16); radius: ui.px(8); tooltip: "Close (Esc)"; onClicked: root.close() }
    }
    Flickable {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: header.bottom
      anchors.bottom: parent.bottom
      contentHeight: contentColumn.implicitHeight + ui.px(38)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: contentColumn
        x: ui.px(20)
        y: ui.px(18)
        width: parent.width - ui.px(40)
        spacing: ui.px(13)
      }
    }
  }
}

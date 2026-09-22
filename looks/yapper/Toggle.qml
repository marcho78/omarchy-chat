import QtQuick
import "../../shared/Palettes.js" as Palettes

// The 38 × 22 switch from the mock.
Item {
  id: root
  property var c: Palettes.fallback()
  property bool checked: false
  signal toggled()
  Ui { id: ui }
  width: ui.px(38)
  height: ui.px(22)
  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: root.checked ? root.c.accent : root.c.surface
    Behavior on color { ColorAnimation { duration: 150 } }
    Rectangle {
      x: root.checked ? parent.width - width - ui.px(3) : ui.px(3)
      anchors.verticalCenter: parent.verticalCenter
      width: ui.px(16); height: ui.px(16); radius: width / 2
      color: root.checked ? root.c.bg2 : root.c.muted
      Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }
  }
  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}

import QtQuick
import "../../shared/Palettes.js" as Palettes

// A bordered card on bg2, the mock's settings block. Children go in the
// padded column.
Rectangle {
  id: root
  property var c: Palettes.fallback()
  property real padding: ui.px(16)
  property real spacing: ui.px(10)
  property color ring: root.c.line
  default property alias content: column.data
  Ui { id: ui }
  implicitHeight: column.implicitHeight + padding * 2
  radius: ui.px(10)
  color: root.c.bg2
  border.width: 1
  border.color: ring
  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.padding
    spacing: root.spacing
  }
}

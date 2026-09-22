import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// A square hover button around one Phosphor icon: the mock's 34 px and
// 38 px buttons. `active` paints the selected state; `subtle` buttons
// rest muted and turn to text color on hover, the others to accent.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property string icon: ""
  property string weight: "regular"
  property real size: ui.px(34)
  property real iconSize: ui.px(17)
  property real radius: ui.px(8)
  property bool active: false
  property bool subtle: true
  property bool bordered: false
  property color fill: "transparent"
  property string tooltip: ""
  property string tipSide: "bottom"
  signal clicked()
  Ui { id: ui }

  width: size
  height: size

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.active ? root.c.sel : (mouse.containsMouse ? root.c.hover : root.fill)
    border.width: root.bordered ? 1 : 0
    border.color: root.c.line
  }
  Icon {
    anchors.centerIn: parent
    name: root.icon
    weight: root.weight
    size: root.iconSize
    color: root.active ? root.c.accent : (mouse.containsMouse ? (root.subtle ? root.c.fg : root.c.accent) : root.c.muted)
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    onContainsMouseChanged: {
      if (!root.tips || root.tooltip === "") return
      if (containsMouse) root.tips.show(root, root.tooltip, root.tipSide); else root.tips.hide(root)
    }
  }
}

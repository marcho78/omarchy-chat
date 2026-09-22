import QtQuick
import "../../shared/Palettes.js" as Palettes

// Hover labels for icon-only buttons. One of these sits at the window's
// top level so a label is never hidden under a neighbouring pane.
Item {
  id: root
  property var c: Palettes.fallback()
  property var owner: null
  property string text: ""
  property string side: "bottom"
  Ui { id: ui }

  function show(item, label, side) { root.owner = item; root.text = label; root.side = side || "bottom"; delay.restart() }
  function hide(item) {
    if (item !== undefined && item !== root.owner) return
    delay.stop(); label.visible = false; root.owner = null
  }

  Timer {
    id: delay
    interval: 450
    onTriggered: {
      if (!root.owner) return
      var p = root.owner.mapToItem(root, 0, 0)
      var x = root.side === "right" ? p.x + root.owner.width + ui.px(8) : p.x + (root.owner.width - label.width) / 2
      var y = root.side === "right" ? p.y + (root.owner.height - label.height) / 2 : p.y + root.owner.height + ui.px(6)
      label.x = Math.max(ui.px(4), Math.min(root.width - label.width - ui.px(4), x))
      label.y = Math.max(ui.px(4), Math.min(root.height - label.height - ui.px(4), y))
      label.visible = true
    }
  }
  Rectangle {
    id: label
    visible: false
    z: 100
    width: labelText.implicitWidth + ui.px(16)
    height: ui.px(24)
    radius: ui.px(6)
    color: root.c.surface
    border.width: 1
    border.color: root.c.line
    Text {
      id: labelText
      anchors.centerIn: parent
      text: root.text
      color: root.c.fg
      font.family: ui.sans
      font.pixelSize: ui.f11
    }
  }
}

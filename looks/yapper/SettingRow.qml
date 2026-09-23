import QtQuick
import "../../shared/Palettes.js" as Palettes

// One settings row: label and description on the left, the control on
// the right, a line underneath. The control is whatever child is given.
Item {
  id: root
  property var c: Palettes.fallback()
  property string label: ""
  property string description: ""
  property color labelColor: root.c.fg
  default property alias control: slot.data
  Ui { id: ui }
  width: parent ? parent.width : ui.px(600)
  implicitHeight: Math.max(labels.implicitHeight, slot.childrenRect.height) + ui.px(26)

  Column {
    id: labels
    anchors.left: parent.left
    anchors.leftMargin: ui.px(2)
    anchors.right: slot.left
    anchors.rightMargin: ui.px(18)
    anchors.verticalCenter: parent.verticalCenter
    spacing: ui.px(3)
    Text { textFormat: Text.PlainText; width: parent.width; text: root.label; color: root.labelColor; wrapMode: Text.Wrap; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.Medium }
    Text { textFormat: Text.PlainText; visible: root.description !== ""; width: parent.width; text: root.description; color: root.c.muted; wrapMode: Text.Wrap; lineHeight: 1.3; font.family: ui.sans; font.pixelSize: ui.f11 }
  }
  Item {
    id: slot
    anchors.right: parent.right
    anchors.rightMargin: ui.px(2)
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }
  Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
}

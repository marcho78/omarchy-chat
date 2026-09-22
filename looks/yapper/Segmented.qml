import QtQuick
import "../../shared/Palettes.js" as Palettes

// A pill group: one of a few options, the chosen one filled with accent.
Rectangle {
  id: root
  property var c: Palettes.fallback()
  property var options: []        // [{ value, label }]
  property string value: ""
  signal chosen(string value)
  Ui { id: ui }
  implicitWidth: segRow.implicitWidth + ui.px(6)
  implicitHeight: ui.px(30)
  radius: height / 2
  color: root.c.chip
  Row {
    id: segRow
    anchors.centerIn: parent
    spacing: ui.px(2)
    Repeater {
      model: root.options
      delegate: Rectangle {
        required property var modelData
        readonly property bool on: String(modelData.value) === root.value
        width: segText.implicitWidth + ui.px(24)
        height: ui.px(24)
        radius: height / 2
        color: on ? root.c.accent : (segMouse.containsMouse ? root.c.hover : "transparent")
        Text { id: segText; anchors.centerIn: parent; text: parent.modelData.label; color: parent.on ? root.c.bg2 : root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11; font.weight: parent.on ? Font.DemiBold : Font.Normal }
        MouseArea { id: segMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen(String(parent.modelData.value)) }
      }
    }
  }
}

import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// A drop-down: the chosen option in a field-like box; clicking unfolds the
// list underneath (inline, so it works inside a scrolling page).
Item {
  id: root
  property var c: Palettes.fallback()
  property var options: []        // [{ value, label }]
  property string value: ""
  property string placeholder: "Choose…"
  property bool open: false
  signal chosen(string value)
  Ui { id: ui }

  readonly property string currentLabel: {
    for (var i = 0; i < options.length; i++) if (String(options[i].value) === value) return String(options[i].label)
    return value !== "" ? value : placeholder
  }
  width: ui.px(250)
  implicitHeight: box.height + (open ? list.height + ui.px(4) : 0)

  Rectangle {
    id: box
    width: parent.width
    height: ui.px(34)
    radius: ui.px(8)
    color: root.c.bg2
    border.width: 1
    border.color: root.open || boxMouse.containsMouse ? root.c.accent : root.c.line
    Text {
      anchors.left: parent.left
      anchors.leftMargin: ui.px(11)
      anchors.right: caret.left
      anchors.rightMargin: ui.px(6)
      anchors.verticalCenter: parent.verticalCenter
      text: root.currentLabel
      color: root.value === "" && root.currentLabel === root.placeholder ? root.c.muted : root.c.fg
      elide: Text.ElideRight
      font.family: ui.sans; font.pixelSize: ui.px(12.5)
    }
    Icon { id: caret; anchors.right: parent.right; anchors.rightMargin: ui.px(10); anchors.verticalCenter: parent.verticalCenter; name: root.open ? "caret-up" : "caret-down"; size: ui.px(12); color: root.c.muted }
    MouseArea { id: boxMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
  }
  Rectangle {
    id: list
    anchors.top: box.bottom
    anchors.topMargin: ui.px(4)
    width: parent.width
    visible: root.open
    height: visible ? Math.min(listColumn.implicitHeight + ui.px(8), ui.px(260)) : 0
    radius: ui.px(8)
    color: root.c.bg2
    border.width: 1
    border.color: root.c.line
    clip: true
    Flickable {
      anchors.fill: parent
      anchors.margins: ui.px(4)
      contentHeight: listColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      Column {
        id: listColumn
        width: parent.width
        Repeater {
          model: root.options
          delegate: Rectangle {
            required property var modelData
            readonly property bool on: String(modelData.value) === root.value
            width: parent.width
            height: ui.px(30)
            radius: ui.px(6)
            color: on ? root.c.sel : (optMouse.containsMouse ? root.c.hover : "transparent")
            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.leftMargin: ui.px(9)
              anchors.right: check.left
              anchors.rightMargin: ui.px(6)
              anchors.verticalCenter: parent.verticalCenter
              text: parent.modelData.label
              color: parent.on ? root.c.accent : root.c.fg
              elide: Text.ElideRight
              font.family: ui.sans; font.pixelSize: ui.px(12.5)
            }
            Icon { id: check; anchors.right: parent.right; anchors.rightMargin: ui.px(9); anchors.verticalCenter: parent.verticalCenter; visible: parent.on; name: "check"; weight: "bold"; size: ui.px(12); color: root.c.accent }
            MouseArea { id: optMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.open = false; root.chosen(String(parent.modelData.value)) } }
          }
        }
      }
    }
  }
}

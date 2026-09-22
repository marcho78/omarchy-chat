import QtQuick
import "../../shared/Palettes.js" as Palettes
import "../../shared"

// A single-line text field in the Yapper look: the mock's 34 px box
// with a line border that turns accent on focus.
Rectangle {
  id: root
  property var c: Palettes.fallback()
  property alias text: input.text
  property alias placeholder: placeholderText.text
  property alias maximumLength: input.maximumLength
  property alias hasFocus: input.activeFocus
  property alias echoMode: input.echoMode
  property alias inputMethodHints: input.inputMethodHints
  property string icon: ""
  signal accepted()
  signal escaped()
  function forceActiveFocus() { input.forceActiveFocus() }
  function selectAll() { input.selectAll() }
  Ui { id: ui }

  implicitHeight: ui.px(34)
  radius: ui.px(8)
  color: root.c.bg
  border.width: 1
  border.color: input.activeFocus ? root.c.accent : root.c.line

  Icon {
    id: leadingIcon
    anchors.left: parent.left
    anchors.leftMargin: ui.px(10)
    anchors.verticalCenter: parent.verticalCenter
    visible: root.icon !== ""
    name: root.icon
    size: ui.px(14)
    color: root.c.muted
  }
  TextInput {
    id: input
    anchors.left: leadingIcon.visible ? leadingIcon.right : parent.left
    anchors.leftMargin: leadingIcon.visible ? ui.px(8) : ui.px(10)
    anchors.right: parent.right
    anchors.rightMargin: ui.px(10)
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    color: root.c.fg
    selectionColor: root.c.sel
    selectedTextColor: root.c.fg
    font.family: ui.sans
    font.pixelSize: ui.f13
    onAccepted: root.accepted()
    Keys.onEscapePressed: function(event) { event.accepted = true; root.escaped() }
    Text {
      id: placeholderText
      anchors.fill: parent
      visible: input.text === ""
      color: root.c.muted
      font: input.font
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
  }
}

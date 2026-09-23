import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// The look's pill button: plain (line border), primary (accent fill),
// warn or danger fills. Text with an optional leading icon.
Rectangle {
  id: root
  property var c: Palettes.fallback()
  property string label: ""
  property string icon: ""
  property string iconWeight: "regular"
  property bool primary: false
  property bool danger: false
  property bool warn: false
  property bool round: false
  property string tooltip: ""
  property var tips: null
  signal clicked()
  Ui { id: ui }

  readonly property bool filled: primary || danger || warn
  readonly property color fillColor: primary ? root.c.accent : danger ? root.c.bad : root.c.warn
  implicitWidth: pillRow.implicitWidth + ui.px(round ? 30 : 22)
  implicitHeight: ui.px(round ? 34 : 30)
  radius: round ? height / 2 : ui.px(7)
  opacity: enabled ? 1 : 0.5
  color: filled ? (pillMouse.containsMouse ? Qt.lighter(fillColor, 1.1) : fillColor) : (pillMouse.containsMouse ? root.c.hover : "transparent")
  border.width: filled ? 0 : 1
  border.color: root.c.line
  Row {
    id: pillRow
    anchors.centerIn: parent
    spacing: ui.px(6)
    Icon { anchors.verticalCenter: parent.verticalCenter; visible: root.icon !== ""; name: root.icon; weight: root.iconWeight; size: ui.px(13); color: root.filled ? root.c.bg2 : root.c.fg }
    Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: root.label; color: root.filled ? root.c.bg2 : root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: root.filled ? Font.DemiBold : Font.Normal }
  }
  MouseArea {
    id: pillMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    onContainsMouseChanged: { if (!root.tips || root.tooltip === "") return; if (containsMouse) root.tips.show(root, root.tooltip); else root.tips.hide(root) }
  }
}

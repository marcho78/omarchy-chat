import QtQuick
import "../../shared/Palettes.js" as Palettes

// A range control (LevelSlider, distinct from Controls' Slider): the accent fills up to the knob. `moved` fires while
// dragging with the live value, `released` once with the final one.
Item {
  id: root
  property var c: Palettes.fallback()
  property real from: 0
  property real to: 100
  property real step: 1
  property real value: 0
  readonly property bool dragging: mouse.pressed
  property real liveValue: value
  signal moved(real value)
  signal released(real value)
  Ui { id: ui }
  width: ui.px(160)
  height: ui.px(22)

  function snap(v) { var s = Math.max(0.0001, step); return Math.max(from, Math.min(to, Math.round(v / s) * s)) }
  function valueAt(x) { return snap(from + (to - from) * Math.max(0, Math.min(1, (x - ui.px(8)) / (width - ui.px(16))))) }
  readonly property real shown: dragging ? liveValue : value
  readonly property real ratio: to > from ? (shown - from) / (to - from) : 0

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: ui.px(8)
    anchors.rightMargin: ui.px(8)
    height: ui.px(4)
    radius: ui.px(2)
    color: root.c.surface
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * root.ratio; radius: ui.px(2); color: root.c.accent }
  }
  Rectangle {
    x: ui.px(8) + (root.width - ui.px(16)) * root.ratio - width / 2
    anchors.verticalCenter: parent.verticalCenter
    width: ui.px(16); height: ui.px(16); radius: width / 2
    color: root.c.accent
    border.width: 2
    border.color: root.c.bg
    scale: mouse.pressed || mouse.containsMouse ? 1.15 : 1
    Behavior on scale { NumberAnimation { duration: 100 } }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // The settings page scrolls; without this a drag becomes a flick.
    preventStealing: true
    onPressed: function(m) { root.liveValue = root.valueAt(m.x); root.moved(root.liveValue) }
    onPositionChanged: function(m) { if (pressed) { root.liveValue = root.valueAt(m.x); root.moved(root.liveValue) } }
    onReleased: root.released(root.liveValue)
  }
}

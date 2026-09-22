import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// The mock's color picker (HsvPicker, distinct from the shared ColorPicker): a saturation/value square, a hue bar, the
// swatch with its hex, and Use / Reset. `picked(hex)` fires on Use,
// `cleared()` on Reset.
Rectangle {
  id: root
  property var c: Palettes.fallback()
  property color value: "#888888"
  property string useLabel: "Use this color"
  // `changed` fires as the color moves (for a live preview); `picked` on
  // Use; `cleared` on Reset.
  signal changed(string hex)
  signal picked(string hex)
  signal cleared()
  Ui { id: ui }

  // Working HSV; edits move these, the swatch follows.
  property real hue: 0
  property real sat: 0
  property real val: 0.5
  property bool syncing: false
  function load(col) {
    syncing = true
    var q = Qt.color(col)
    hue = Math.max(0, q.hsvHue); sat = q.hsvSaturation; val = q.hsvValue
    syncing = false
  }
  Component.onCompleted: load(value)
  onValueChanged: if (!syncing) load(value)
  readonly property string hex: String(Qt.hsva(hue, sat, val, 1))
  readonly property bool hasTextFocus: hexInput.activeFocus

  implicitHeight: pickerRow.implicitHeight + ui.px(32)
  radius: ui.px(10)
  color: root.c.bg2
  border.width: 1
  border.color: root.c.accent

  Flow {
    id: pickerRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: ui.px(16)
    spacing: ui.px(16)

    Rectangle {
      id: square
      width: ui.px(200)
      height: ui.px(150)
      radius: ui.px(8)
      clip: true
      color: Qt.hsva(root.hue, 1, 1, 1)
      Rectangle {
        anchors.fill: parent
        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: "#ffffff" } GradientStop { position: 1.0; color: "#00ffffff" } }
      }
      Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0.0; color: "#00000000" } GradientStop { position: 1.0; color: "#000000" } }
      }
      Rectangle {
        x: root.sat * square.width - width / 2
        y: (1 - root.val) * square.height - height / 2
        width: ui.px(13); height: width; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: "#ffffff"
        Rectangle { anchors.fill: parent; anchors.margins: -1; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.5) }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        preventStealing: true
        function pick(m) { root.sat = Math.max(0, Math.min(1, m.x / width)); root.val = Math.max(0, Math.min(1, 1 - m.y / height)); root.changed(root.hex) }
        onPressed: function(m) { pick(m) }
        onPositionChanged: function(m) { if (pressed) pick(m) }
      }
    }

    Column {
      width: Math.max(ui.px(190), pickerRow.width - square.width - pickerRow.spacing)
      spacing: ui.px(12)
      Rectangle {
        id: hueBar
        width: parent.width
        height: ui.px(14)
        radius: height / 2
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.000; color: "#ff0000" }
          GradientStop { position: 0.167; color: "#ffff00" }
          GradientStop { position: 0.333; color: "#00ff00" }
          GradientStop { position: 0.500; color: "#00ffff" }
          GradientStop { position: 0.667; color: "#0000ff" }
          GradientStop { position: 0.833; color: "#ff00ff" }
          GradientStop { position: 1.000; color: "#ff0000" }
        }
        Rectangle {
          x: root.hue * hueBar.width - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: ui.px(12); height: hueBar.height + 6; radius: width / 2
          color: Qt.hsva(root.hue, 1, 1, 1)
          border.width: 2
          border.color: "#ffffff"
        }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          preventStealing: true
          cursorShape: Qt.PointingHandCursor
          function pick(m) { root.hue = Math.max(0, Math.min(0.9999, (m.x - 4) / hueBar.width)); root.changed(root.hex) }
          onPressed: function(m) { pick(m) }
          onPositionChanged: function(m) { if (pressed) pick(m) }
        }
      }
      Row {
        width: parent.width
        spacing: ui.px(10)
        Rectangle { width: ui.px(38); height: ui.px(38); radius: ui.px(9); color: root.hex; border.width: 1; border.color: root.c.line }
        Rectangle {
          width: parent.width - ui.px(48)
          height: ui.px(38)
          radius: ui.px(7)
          color: root.c.bg
          border.width: 1
          border.color: hexInput.activeFocus ? root.c.accent : root.c.line
          TextInput {
            id: hexInput
            anchors.fill: parent
            anchors.margins: ui.px(12)
            verticalAlignment: TextInput.AlignVCenter
            text: root.hex
            color: root.c.fg
            selectionColor: root.c.sel
            selectedTextColor: root.c.fg
            maximumLength: 7
            font.family: ui.mono; font.pixelSize: ui.f13
            onAccepted: apply()
            onActiveFocusChanged: if (!activeFocus) apply()
            function apply() {
              var t = text.trim().toLowerCase()
              if (t.charAt(0) !== "#") t = "#" + t
              if (!/^#[0-9a-f]{6}$/.test(t)) { text = root.hex; return }
              if (t !== root.hex) { root.load(t); root.changed(root.hex) }
            }
          }
        }
      }
      Row {
        width: parent.width
        spacing: ui.px(8)
        PillButton { c: root.c; label: root.useLabel; primary: true; onClicked: root.picked(root.hex) }
        PillButton { c: root.c; label: "Reset"; onClicked: root.cleared() }
      }
    }
  }
}

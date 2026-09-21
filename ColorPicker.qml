import QtQuick
import qs.Commons
import qs.Ui

// A colour picker: hue bar, saturation/value square, theme swatches and a
// hex field, all kept in sync. Emits picked(hex) on every change and
// cleared() for "use the theme's colour".
Column {
  id: root
  property color value: "#888888"
  property string fontFamily: Style.font.family
  property color fg: Color.foreground
  property var swatches: []      // [{ label, color }]

  signal picked(string hex)
  signal cleared()

  spacing: Style.space(10)

  // Working HSV; edits move these, `value` follows.
  property real hue: 0
  property real sat: 0
  property real val: 0.5
  property bool syncing: false

  function load(c) {
    syncing = true
    var col = Qt.color(c)
    hue = Math.max(0, col.hsvHue)
    sat = col.hsvSaturation
    val = col.hsvValue
    syncing = false
  }
  Component.onCompleted: load(value)
  onValueChanged: if (!syncing) load(value)

  function commit() {
    syncing = true
    var c = Qt.hsva(hue, sat, val, 1)
    root.value = c
    syncing = false
    root.picked(String(c))
  }

  readonly property string hex: String(Qt.hsva(hue, sat, val, 1))

  // Saturation / value square
  Rectangle {
    id: square
    width: parent.width
    height: Style.space(150)
    radius: Style.space(8)
    clip: true
    color: Qt.hsva(root.hue, 1, 1, 1)

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#ffffff" }
        GradientStop { position: 1.0; color: "#00ffffff" }
      }
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#00000000" }
        GradientStop { position: 1.0; color: "#000000" }
      }
    }
    // Cursor
    Rectangle {
      x: root.sat * square.width - width / 2
      y: (1 - root.val) * square.height - height / 2
      width: Style.space(16)
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 2
      border.color: root.val > 0.55 && root.sat < 0.6 ? "#000000" : "#ffffff"
      Rectangle { anchors.centerIn: parent; width: parent.width - 4; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: parent.border.color === "#000000" ? "#ffffff" : "#000000"; opacity: 0.5 }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.CrossCursor
      function pick(m) {
        root.sat = Math.max(0, Math.min(1, m.x / width))
        root.val = Math.max(0, Math.min(1, 1 - m.y / height))
        root.commit()
      }
      onPressed: function(m) { pick(m) }
      onPositionChanged: function(m) { if (pressed) pick(m) }
    }
  }

  // Hue bar
  Rectangle {
    id: hueBar
    width: parent.width
    height: Style.space(18)
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
      width: Style.space(12)
      height: hueBar.height + 6
      radius: width / 2
      color: Qt.hsva(root.hue, 1, 1, 1)
      border.width: 2
      border.color: "#ffffff"
    }
    MouseArea {
      anchors.fill: parent
      anchors.margins: -4
      function pick(m) { root.hue = Math.max(0, Math.min(0.9999, (m.x - 4) / hueBar.width)); root.commit() }
      onPressed: function(m) { pick(m) }
      onPositionChanged: function(m) { if (pressed) pick(m) }
    }
  }

  // Theme swatches
  Flow {
    width: parent.width
    spacing: Style.space(8)
    visible: root.swatches.length > 0
    Repeater {
      model: root.swatches
      delegate: Rectangle {
        required property var modelData
        width: Style.space(30)
        height: width
        radius: Style.space(8)
        color: modelData.color
        border.width: String(Qt.color(modelData.color)) === root.hex ? 2 : 1
        border.color: String(Qt.color(modelData.color)) === root.hex ? Color.accent : Util.alpha(root.fg, 0.35)
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.value = parent.modelData.color; root.picked(String(Qt.color(parent.modelData.color))) }
          onEntered: tip.visible = true
          onExited: tip.visible = false
        }
        Rectangle {
          id: tip
          visible: false
          anchors.bottom: parent.top
          anchors.bottomMargin: 4
          anchors.horizontalCenter: parent.horizontalCenter
          width: tipText.implicitWidth + 12
          height: tipText.implicitHeight + 6
          radius: 4
          color: Color.tooltip.background
          border.color: Color.tooltip.border
          border.width: 1
          Text { id: tipText; anchors.centerIn: parent; text: String(parent.parent.modelData.label); color: Color.tooltip.text; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        }
      }
    }
  }

  // Preview + hex + reset
  Row {
    width: parent.width
    spacing: Style.spacing.controlGap
    Rectangle {
      width: Style.spacing.controlHeight
      height: Style.spacing.controlHeight
      radius: Style.space(8)
      color: root.value
      border.width: 1
      border.color: Util.alpha(root.fg, 0.35)
    }
    TextField {
      id: hexField
      width: Style.space(110)
      maximumLength: 9
      text: root.hex
      onAccepted: apply()
      onActiveFocusChanged: if (!activeFocus) apply()
      function apply() {
        var t = text.trim().toLowerCase()
        if (t.charAt(0) !== "#") t = "#" + t
        if (!/^#[0-9a-f]{6}$/.test(t)) { text = root.hex; return }
        if (t === root.hex) return
        root.value = t
        root.picked(t)
      }
    }
    Button {
      text: "Use theme colour"
      onClicked: root.cleared()
    }
  }
  readonly property bool hasTextFocus: hexField.activeFocus
}

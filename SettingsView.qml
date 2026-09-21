import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Settings, rendered from the manifest schema: booleans as toggles, enums
// as dropdowns, integers as sliders, strings and paths as text fields.
// Each change is written to shell.json at once and applies live.
Column {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family

  spacing: Style.space(10)

  readonly property bool hasTextFocus: {
    for (var i = 0; i < fields.count; i++) {
      var it = fields.itemAt(i)
      if (it && it.textFocus) return true
    }
    return false
  }

  function current(key, fallback) { return root.service ? root.service.setting(key, fallback) : fallback }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    text: "Changes apply immediately. Colours are hex like #101315 and only count under Custom appearance; leave one empty to keep the theme's."
    color: root.fg
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    id: fields
    model: root.service ? root.service.schema : []
    delegate: Column {
      id: field
      required property var modelData
      readonly property string key: String(modelData.key)
      readonly property string type: String(modelData.type)
      readonly property var value: root.current(key, modelData.defaultValue)
      readonly property bool textFocus: textField.activeFocus
      width: root.width
      spacing: Style.space(4)

      // boolean
      Toggle {
        visible: field.type === "boolean"
        width: parent.width
        label: String(field.modelData.label || field.key)
        description: String(field.modelData.description || "")
        checked: field.value === true || String(field.value) === "true"
        onClicked: root.service.set(field.key, !checked)
      }

      // enum
      Column {
        visible: field.type === "enum"
        width: parent.width
        spacing: Style.space(4)
        Text {
          text: String(field.modelData.label || field.key)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }
        Dropdown {
          width: parent.width
          options: field.modelData.options || []
          value: String(field.value)
          onChanged: function(v) { root.service.set(field.key, v) }
        }
        Text {
          visible: !!field.modelData.description
          width: parent.width
          wrapMode: Text.WordWrap
          text: String(field.modelData.description || "")
          color: root.fg
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // integer
      Column {
        visible: field.type === "integer"
        width: parent.width
        spacing: Style.space(2)
        Row {
          width: parent.width
          Text {
            text: String(field.modelData.label || field.key)
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
          Item { width: parent.width - parent.children[0].implicitWidth - valueLabel.implicitWidth; height: 1 }
          Text {
            id: valueLabel
            text: String(Number(field.value) || field.modelData.defaultValue || 0) + (field.key === "fontScale" ? "%" : "")
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
        }
        PanelSlider {
          width: parent.width
          minimum: Number(field.modelData.min !== undefined ? field.modelData.min : 0)
          maximum: Number(field.modelData.max !== undefined ? field.modelData.max : 100)
          step: Number(field.modelData.step || 1)
          integer: true
          value: Number(field.value) || 0
          onReleased: function(v) { root.service.set(field.key, Math.round(v)) }
        }
      }

      // string / path
      Column {
        visible: field.type === "string" || field.type === "path"
        width: parent.width
        spacing: Style.space(4)
        Text {
          text: String(field.modelData.label || field.key)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }
        Row {
          width: parent.width
          spacing: Style.spacing.controlGap
          TextField {
            id: textField
            width: parent.width - (swatch.visible ? swatch.width + Style.spacing.controlGap : 0)
            text: String(field.value === undefined || field.value === null ? "" : field.value)
            placeholderText: String(field.modelData.description || "")
            maximumLength: 512
            onAccepted: root.service.set(field.key, text)
            onActiveFocusChanged: if (!activeFocus && text !== String(field.value || "")) root.service.set(field.key, text)
          }
          // A live swatch for colour fields
          Rectangle {
            id: swatch
            visible: /Color$/.test(field.key)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.spacing.controlHeight
            height: Style.spacing.controlHeight
            radius: Style.space(6)
            border.width: 1
            border.color: root.fg
            color: root.service && root.service.isHex(textField.text) ? textField.text : "transparent"
            Text {
              anchors.centerIn: parent
              visible: !(root.service && root.service.isHex(textField.text))
              text: "—"
              color: root.fg
              opacity: 0.4
              font.family: root.fontFamily
            }
          }
        }
        Text {
          visible: !!field.modelData.description && field.type !== "string"
          width: parent.width
          wrapMode: Text.WordWrap
          text: String(field.modelData.description || "")
          color: root.fg
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
